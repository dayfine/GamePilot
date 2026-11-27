module AC = Bdsp_rng.Advance_clock
module SE = Bdsp_rng.Static_encounter
module SPS = Bdsp_rng.Static_press_schedule
module ST = Bdsp_rng.Static_targets
module STL = Bdsp_rng.Static_timeline
module XS = Bdsp_rng.Xorshift128
module ICR = In_chamber_reidentifier

type search_config = {
  tsv : int;
  synchronize_nature : int option;
  min_wait_advances : int;
  max_wait_advances : int;
  accept : SE.pokemon -> bool;
}

type config = {
  target : ST.t;
  search : search_config;
  timings : SPS.timings;
  white_delay_seconds : float;
  advance_delay : int;
  aim_offset_ms : float;
  lease_renew_seconds : float;
}

type plan = {
  hit : SE.hit;
  timeline_start_advance : int;
  schedule : SPS.t;
  open_t_ms : float;
  confirm_t_ms : float;
}

type outcome = { plan : plan; batch_done : Wire.batch_done }

let ms_per_s = 1000.0
let poll_timeout_ms = 500
let press_hold_ms = 100
let press_cooldown_ms = 150
let min_prep_advances = 10
let span_extra_events = 10
let wait_margin_factor = 1.5
let wait_margin_extra_s = 20.0

let default_config ~target ~accept =
  {
    target;
    search =
      {
        tsv = 0;
        synchronize_nature = None;
        min_wait_advances = 20;
        max_wait_advances = 3000;
        accept;
      };
    timings = SPS.default_timings;
    white_delay_seconds = 0.0;
    advance_delay = 0;
    aim_offset_ms = 0.0;
    lease_renew_seconds = 30.0;
  }

let timeline_context config (anchor : ICR.anchor) : STL.context =
  let pokemon_models =
    match config.target.default_trigger with
    | ST.Direct_no_pokemon_model -> 0
    | ST.Timeline_single_confirm -> 1
  in
  {
    npcs = 1;
    pokemon_models;
    white_delay_seconds = config.white_delay_seconds;
    advance_delay = config.advance_delay;
    advances_after_accept = config.target.advances_after_accept;
    tick_seconds = anchor.fitted_tick_seconds;
  }

let state_at base_state advance =
  let rng = XS.create base_state in
  XS.advance rng advance;
  XS.state rng

let max_span_for config (context : STL.context) =
  let max_events =
    int_of_float (Float.ceil (config.timings.max_wait_seconds *. 2.0))
    + span_extra_events
  in
  context.advance_delay + context.advances_after_accept + max_events

let rec find_start_for_hit config ~context ~min_start ~base_state (hit : SE.hit)
    candidate =
  let min_span = context.STL.advance_delay + context.advances_after_accept in
  let max_start = hit.advances - min_span in
  if candidate > max_start then None
  else
    let st = state_at base_state candidate in
    match
      SPS.schedule ~trigger_kind:config.target.default_trigger ~context
        ~timings:config.timings st
    with
    | Ok sched when candidate + sched.span = hit.advances ->
        Some (candidate, sched)
    | _ ->
        find_start_for_hit config ~context ~min_start ~base_state hit
          (candidate + 1)

let schedule_for_hit config ~context ~min_start ~base_state (hit : SE.hit) =
  let earliest = max min_start (hit.advances - max_span_for config context) in
  find_start_for_hit config ~context ~min_start ~base_state hit earliest

let rec first_reachable config ~context ~min_start ~base_state = function
  | [] ->
      Error "Static_rng_trigger: no reachable target advance in search range"
  | hit :: rest -> (
      match schedule_for_hit config ~context ~min_start ~base_state hit with
      | Some (timeline_start_advance, schedule) ->
          Ok (hit, timeline_start_advance, schedule)
      | None -> first_reachable config ~context ~min_start ~base_state rest)

let midpoint_of_event (anchor : ICR.anchor) ~rel_index events =
  match List.nth_opt events rel_index with
  | None -> Error "Static_rng_trigger: timeline horizon too short for open"
  | Some (ev : STL.event) ->
      let prev_s =
        if rel_index = 0 then 0.0
        else (List.nth events (rel_index - 1)).time_seconds
      in
      let mid_s = (prev_s +. ev.time_seconds) /. 2.0 in
      Ok (anchor.anchor_time_ms +. (mid_s *. ms_per_s))

let open_time_1pk (anchor : ICR.anchor) ~target_advance =
  let anchor_after = anchor.advances_to_last_blink + 1 in
  let rel_index = target_advance - anchor_after in
  let st = state_at anchor.base_state anchor_after in
  let first_pk =
    (anchor.next_pokemon_blink_min_seconds
   +. anchor.next_pokemon_blink_max_seconds)
    /. 2.0
  in
  let duration_seconds =
    float_of_int (max 1 rel_index)
    *. anchor.fitted_tick_seconds *. wait_margin_factor
    +. wait_margin_extra_s
  in
  Result.bind
    (STL.simulate_from_phase st ~tick_seconds:anchor.fitted_tick_seconds
       ~first_player_tick_seconds:anchor.fitted_tick_seconds
       ~first_pokemon_blink_seconds:first_pk ~duration_seconds)
    (midpoint_of_event anchor ~rel_index)

let open_time_direct (anchor : ICR.anchor) ~target_advance =
  let clock : AC.t =
    {
      anchor_time = anchor.anchor_time_ms /. ms_per_s;
      anchor_advance = anchor.advances_to_last_blink;
      tick_seconds = anchor.fitted_tick_seconds;
      npcs = 1;
    }
  in
  Ok (AC.middle_of_advance clock target_advance *. ms_per_s)

let compute_open_t_ms config (anchor : ICR.anchor) ~target_advance =
  match config.target.default_trigger with
  | ST.Direct_no_pokemon_model -> open_time_direct anchor ~target_advance
  | ST.Timeline_single_confirm -> open_time_1pk anchor ~target_advance

let build_plan config (anchor : ICR.anchor)
    (hit, timeline_start_advance, schedule) =
  match
    compute_open_t_ms config anchor ~target_advance:timeline_start_advance
  with
  | Error msg -> Error msg
  | Ok open_t_ms ->
      let confirm_t_ms =
        open_t_ms
        +. (schedule.SPS.confirm_seconds *. ms_per_s)
        +. config.aim_offset_ms
      in
      Ok { hit; timeline_start_advance; schedule; open_t_ms; confirm_t_ms }

let plan config (anchor : ICR.anchor) =
  let searcher =
    SE.searcher anchor.base_state config.target.template ~tsv:config.search.tsv
      ~synchronize_nature:config.search.synchronize_nature
  in
  let min_advances =
    anchor.advances_to_last_blink + config.search.min_wait_advances
  in
  let max_advances =
    anchor.advances_to_last_blink + config.search.max_wait_advances
  in
  let hits =
    SE.scan searcher ~min_advances ~max_advances ~accept:config.search.accept
  in
  let context = timeline_context config anchor in
  let min_start = anchor.advances_to_last_blink + min_prep_advances in
  Result.bind
    (first_reachable config ~context ~min_start ~base_state:anchor.base_state
       hits)
    (build_plan config anchor)

let press_a () =
  [
    Wire.press ~hold_ms:press_hold_ms ~cooldown_ms:press_cooldown_ms [ Wire.A ];
  ]

let rec wait_until_ms ~lease_renew_ms ~last_lease_ms ~target_ms =
  let now_ms = Effects.now () in
  let last_lease_ms =
    if now_ms -. last_lease_ms >= lease_renew_ms then (
      Effects.renew_lease ();
      now_ms)
    else last_lease_ms
  in
  if now_ms >= target_ms then ()
  else (
    ignore
      (Effects.await ~timeout_ms:poll_timeout_ms
         (fun (m : Effects.measurements) -> m.t_ms >= target_ms));
    wait_until_ms ~lease_renew_ms ~last_lease_ms ~target_ms)

let execute_plan config (p : plan) =
  let lease_renew_ms = config.lease_renew_seconds *. ms_per_s in
  wait_until_ms ~lease_renew_ms ~last_lease_ms:(Effects.now ())
    ~target_ms:p.open_t_ms;
  (match config.target.default_trigger with
  | ST.Direct_no_pokemon_model -> ()
  | ST.Timeline_single_confirm -> ignore (Effects.submit (press_a ())));
  let batch_done =
    Effects.submit_at ~start_at_t_ms:p.confirm_t_ms (press_a ())
  in
  Ok { plan = p; batch_done }

let run config anchor = Result.bind (plan config anchor) (execute_plan config)
