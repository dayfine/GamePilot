module EBR = Bdsp_readers.Eye_blink_reader
module BE = Bdsp_rng.Blink_extraction
module BM = Bdsp_rng.Blink_model
module MR = Bdsp_rng.Mixed_reidentifier
module SR = Bdsp_rng.State_reidentifier
module XS = Bdsp_rng.Xorshift128

type search_bounds = {
  search_min : int;
  search_max : int;
  min_blinks : int;
  max_blinks : int;
  tick_seconds : float option;
  order_swap_tolerance : float;
}

type config = {
  picture : Wire.box;
  target : EBR.target;
  base_state : XS.state;
  bounds : search_bounds;
  threshold : float;
  timeout_seconds : float;
  lease_renew_seconds : float;
}

type anchor = {
  base_state : XS.state;
  anchor_time_ms : float;
  advances_to_first_blink : int;
  advances_to_last_blink : int;
  next_pokemon_blink_min_seconds : float;
  next_pokemon_blink_max_seconds : float;
  fitted_tick_seconds : float;
  gaps : BE.frame_gap list;
}

let ms_per_s = 1000.0
let poll_timeout_ms = 1000
let check_period_s = 1.0
let double_blink_window_s = 0.55
let tick_gap_margin_s = 0.25

let default_bounds =
  {
    search_min = 0;
    search_max = 40_000;
    min_blinks = 8;
    max_blinks = 24;
    tick_seconds = None;
    order_swap_tolerance = MR.default_order_swap_tolerance;
  }

let default_config ~picture ~target ~base_state =
  {
    picture;
    target;
    base_state;
    bounds = default_bounds;
    threshold = 0.25;
    timeout_seconds = 300.0;
    lease_renew_seconds = 30.0;
  }

type watch_state = {
  start_s : float;
  mutable last_seq : int;
  mutable last_lease_s : float;
  mutable last_check_s : float;
  mutable last_event_count : int;
  mutable samples_rev : BE.match_sample list;
  mutable raw_gaps_rev : Wire.gap list;
}

let make_watch start_s =
  {
    start_s;
    last_seq = -1;
    last_lease_s = start_s;
    last_check_s = start_s;
    last_event_count = 0;
    samples_rev = [];
    raw_gaps_rev = [];
  }

let now_seconds () = Effects.now () /. ms_per_s

let maybe_renew_lease config watch now_s =
  if now_s -. watch.last_lease_s >= config.lease_renew_seconds then (
    Effects.renew_lease ();
    watch.last_lease_s <- now_s)

let drain_gaps watch =
  let incoming = Effects.take_gaps () in
  List.iter (fun g -> watch.raw_gaps_rev <- g :: watch.raw_gaps_rev) incoming

let record_frame config watch (frame : Effects.measurements) =
  watch.last_seq <- frame.seq;
  match EBR.score frame config.target.id with
  | None -> ()
  | Some score ->
      let sample : BE.match_sample =
        { timestamp = frame.t_ms /. ms_per_s; score }
      in
      watch.samples_rev <- sample :: watch.samples_rev

let wire_gaps_of ~origin raw_gaps_rev =
  List.rev_map
    (fun (g : Wire.gap) ->
      {
        BE.start_seconds = (g.from_t_ms /. ms_per_s) -. origin;
        stop_seconds = (g.to_t_ms /. ms_per_s) -. origin;
      })
    raw_gaps_rev

let all_gaps ~origin samples raw_gaps_rev =
  BE.find_frame_gaps ~origin samples @ wire_gaps_of ~origin raw_gaps_rev

let gap_overlaps ~lo ~hi (g : BE.frame_gap) =
  g.stop_seconds >= lo && g.start_seconds <= hi

let has_gap_in gaps ~lo ~hi = List.exists (gap_overlaps ~lo ~hi) gaps

let estimate_period config events =
  match config.bounds.tick_seconds with
  | Some p -> p
  | None -> (
      match BE.fit_tick_period events with
      | Some fit -> fit.period_seconds
      | None -> BM.npc_tick_seconds)

let classify_event gaps ~first_s ~period (ev : BE.blink_event) =
  let rel_s = ev.seconds -. first_s in
  let tick = int_of_float (Float.round (rel_s /. period)) in
  let pre_gap =
    tick > 0
    && has_gap_in gaps ~lo:(ev.seconds -. double_blink_window_s) ~hi:ev.seconds
  in
  if pre_gap then `Drop tick
  else
    let post_gap =
      ev.blink_type = BM.Single
      && has_gap_in gaps ~lo:ev.seconds ~hi:(ev.seconds +. double_blink_window_s)
    in
    let blink_type = if post_gap then None else Some ev.blink_type in
    `Keep ({ MR.seconds = rel_s; blink_type }, ev.seconds)

let gap_unknown_ticks gaps ~first_s ~period ~last_tick =
  let rec collect tick acc =
    if tick >= last_tick then List.rev acc
    else
      let t_k = first_s +. (float_of_int tick *. period) in
      let hit =
        has_gap_in gaps ~lo:(t_k -. tick_gap_margin_s)
          ~hi:(t_k +. tick_gap_margin_s)
      in
      let acc = if hit then tick :: acc else acc in
      collect (tick + 1) acc
  in
  collect 1 []

let build_reid_inputs config ~gaps events =
  let first_s = (List.hd events).BE.seconds in
  let period = estimate_period config events in
  let kept, dropped =
    List.fold_left
      (fun (kept, dropped) ev ->
        match classify_event gaps ~first_s ~period ev with
        | `Keep pair -> (pair :: kept, dropped)
        | `Drop tick -> (kept, tick :: dropped))
      ([], []) events
  in
  let kept = List.rev kept in
  let blinks = List.map fst kept in
  let last_ev_s = match List.rev kept with (_, s) :: _ -> s | [] -> first_s in
  let last_tick =
    int_of_float (Float.round ((last_ev_s -. first_s) /. period))
  in
  let unknown = dropped @ gap_unknown_ticks gaps ~first_s ~period ~last_tick in
  (blinks, unknown, last_ev_s)

let anchor_of (config : config) ~origin ~last_ev_s ~gaps (res : MR.result) =
  {
    base_state = config.base_state;
    anchor_time_ms = (origin +. last_ev_s) *. ms_per_s;
    advances_to_first_blink = res.advances_to_first_blink;
    advances_to_last_blink = res.advances_to_last_blink;
    next_pokemon_blink_min_seconds = res.next_pokemon_blink_min_seconds;
    next_pokemon_blink_max_seconds = res.next_pokemon_blink_max_seconds;
    fitted_tick_seconds = res.fitted_tick_seconds;
    gaps;
  }

let reid_failure_error count (res : MR.result) =
  let msg =
    Printf.sprintf "In_chamber_reidentifier: %s (after %d blinks)"
      res.failure_reason count
  in
  `Done (Error msg)

let run_reid config ~origin ~gaps events =
  let blinks, unknown_ticks, last_ev_s =
    build_reid_inputs config ~gaps events
  in
  let req : MR.request =
    {
      base_state = config.base_state;
      search_min = config.bounds.search_min;
      search_max = config.bounds.search_max;
      blinks;
      unknown_ticks;
      tick_seconds = config.bounds.tick_seconds;
      order_swap_tolerance = config.bounds.order_swap_tolerance;
    }
  in
  let res = SR.reidentify_with_pokemon_models req in
  let count = List.length events in
  if res.success then `Done (Ok (anchor_of config ~origin ~last_ev_s ~gaps res))
  else if count >= config.bounds.max_blinks then reid_failure_error count res
  else `Continue

let check_samples config watch =
  match List.rev watch.samples_rev with
  | [] -> `Continue
  | first :: _ as samples ->
      let origin = first.timestamp in
      let raw = BE.extract_blinks ~origin samples ~threshold:config.threshold in
      let events = BE.group_blinks raw in
      let count = List.length events in
      if count = watch.last_event_count || count < config.bounds.min_blinks then
        `Continue
      else (
        watch.last_event_count <- count;
        let gaps = all_gaps ~origin samples watch.raw_gaps_rev in
        run_reid config ~origin ~gaps events)

let await_next_frame config watch =
  let pred (m : Effects.measurements) = m.seq > watch.last_seq in
  match Effects.await ~timeout_ms:poll_timeout_ms pred with
  | Effects.Holds frame -> record_frame config watch frame
  | Effects.Timeout -> ()

let rec step_after_frame config watch =
  drain_gaps watch;
  let now_s = now_seconds () in
  maybe_renew_lease config watch now_s;
  if now_s -. watch.last_check_s < check_period_s then loop config watch
  else (
    watch.last_check_s <- now_s;
    match check_samples config watch with
    | `Done outcome -> outcome
    | `Continue -> loop config watch)

and loop config watch =
  let now_s = now_seconds () in
  maybe_renew_lease config watch now_s;
  drain_gaps watch;
  if now_s -. watch.start_s >= config.timeout_seconds then
    Error
      (Printf.sprintf "In_chamber_reidentifier: timed out after %.1f s"
         config.timeout_seconds)
  else (
    await_next_frame config watch;
    step_after_frame config watch)

let watch_and_reidentify config () = loop config (make_watch (now_seconds ()))

let run config =
  match EBR.probes ~picture:config.picture [ config.target ] with
  | [] -> Error "In_chamber_reidentifier: eye ROI lies outside game picture"
  | probes -> Effects.with_probes probes (watch_and_reidentify config)
