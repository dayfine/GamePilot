module EBR = Bdsp_readers.Eye_blink_reader
module BE = Bdsp_rng.Blink_extraction
module MR = Bdsp_rng.Mixed_reidentifier
module XS = Bdsp_rng.Xorshift128
module Win = In_chamber_window

type search_bounds = {
  search_min : int;
  search_max : int;
  min_blinks : int;
  max_blinks : int;
  tick_seconds : float option;
  order_swap_tolerance : float;
  max_pk_phase_width_seconds : float option;
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
let trim_extra_blinks = 4
let max_window_resets = 2

let default_bounds =
  {
    search_min = 0;
    search_max = 40_000;
    min_blinks = 8;
    max_blinks = 24;
    tick_seconds = None;
    order_swap_tolerance = MR.default_order_swap_tolerance;
    max_pk_phase_width_seconds = Some 1.0;
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
  mutable resets : int;
  mutable samples_rev : BE.match_sample list;
  mutable raw_gaps_rev : Wire.gap list;
  mutable best_anchor : anchor option;
}

let make_watch start_s =
  {
    start_s;
    last_seq = -1;
    last_lease_s = start_s;
    last_check_s = start_s;
    last_event_count = 0;
    resets = 0;
    samples_rev = [];
    raw_gaps_rev = [];
    best_anchor = None;
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

let reid_failure_error ~gaps (attempt : Win.reid_attempt) =
  let diag =
    Win.format_diagnostics ~blinks:attempt.blinks
      ~unknown_ticks:attempt.unknown_ticks ~gaps
  in
  let msg =
    Printf.sprintf "In_chamber_reidentifier: %s (%s)"
      attempt.result.failure_reason diag
  in
  `Done (Error msg)

let trim_watch watch ~cutoff_s =
  watch.samples_rev <-
    List.filter
      (fun (s : BE.match_sample) -> s.timestamp >= cutoff_s)
      watch.samples_rev;
  watch.raw_gaps_rev <-
    List.filter
      (fun (g : Wire.gap) -> g.to_t_ms /. ms_per_s >= cutoff_s)
      watch.raw_gaps_rev;
  watch.last_event_count <- 0;
  watch.resets <- watch.resets + 1

let handle_no_match config watch ~origin ~gaps ~events ~count attempt =
  let trim_at =
    min config.bounds.max_blinks (config.bounds.min_blinks + trim_extra_blinks)
  in
  if count >= trim_at && watch.resets < max_window_resets then
    match Win.trim_cutoff_seconds ~origin events with
    | Some cutoff_s ->
        trim_watch watch ~cutoff_s;
        `Continue
    | None -> reid_failure_error ~gaps attempt
  else if count >= config.bounds.max_blinks then
    reid_failure_error ~gaps attempt
  else `Continue

let phase_width (a : anchor) =
  a.next_pokemon_blink_max_seconds -. a.next_pokemon_blink_min_seconds

let remember_best_anchor watch candidate =
  let replace =
    match watch.best_anchor with
    | None -> true
    | Some prev -> phase_width candidate <= phase_width prev
  in
  if replace then watch.best_anchor <- Some candidate

let phase_within_limit (config : config) anchor =
  match config.bounds.max_pk_phase_width_seconds with
  | None -> true
  | Some max_w -> phase_width anchor <= max_w

let fallback_or_error watch ~gaps attempt =
  match watch.best_anchor with
  | Some anchor -> `Done (Ok anchor)
  | None -> reid_failure_error ~gaps attempt

let handle_match config watch ~origin ~last_ev_s ~gaps ~count result =
  let candidate = anchor_of config ~origin ~last_ev_s ~gaps result in
  remember_best_anchor watch candidate;
  if phase_within_limit config candidate then `Done (Ok candidate)
  else if count >= config.bounds.max_blinks then
    `Done (Ok (Option.value watch.best_anchor ~default:candidate))
  else `Continue

let evaluate_events (config : config) watch ~origin ~gaps ~events ~count =
  let eval =
    Win.evaluate ~base_state:config.base_state
      ~search_min:config.bounds.search_min ~search_max:config.bounds.search_max
      ~min_blinks:config.bounds.min_blinks
      ~tick_seconds:config.bounds.tick_seconds
      ~order_swap_tolerance:config.bounds.order_swap_tolerance ~gaps events
  in
  match eval with
  | Win.Matched { result; last_ev_s } ->
      handle_match config watch ~origin ~last_ev_s ~gaps ~count result
  | Win.Ambiguous attempt ->
      if count >= config.bounds.max_blinks then
        fallback_or_error watch ~gaps attempt
      else `Continue
  | Win.No_match attempt -> (
      match watch.best_anchor with
      | Some anchor -> `Done (Ok anchor)
      | None ->
          handle_no_match config watch ~origin ~gaps ~events ~count attempt)

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
        evaluate_events config watch ~origin ~gaps ~events ~count)

let samples_diagnostics config watch ~origin samples =
  let raw = BE.extract_blinks ~origin samples ~threshold:config.threshold in
  let events = BE.group_blinks raw in
  let gaps = all_gaps ~origin samples watch.raw_gaps_rev in
  let blinks, unknown_ticks, _ =
    Win.build_reid_inputs ~tick_seconds:config.bounds.tick_seconds ~gaps events
  in
  Win.format_diagnostics ~blinks ~unknown_ticks ~gaps

let timeout_error config watch =
  let diag =
    match List.rev watch.samples_rev with
    | [] ->
        Win.format_diagnostics ~blinks:[] ~unknown_ticks:[]
          ~gaps:(wire_gaps_of ~origin:watch.start_s watch.raw_gaps_rev)
    | first :: _ as samples ->
        samples_diagnostics config watch ~origin:first.timestamp samples
  in
  Error
    (Printf.sprintf "In_chamber_reidentifier: timed out after %.1f s (%s)"
       config.timeout_seconds diag)

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
    match watch.best_anchor with
    | Some anchor -> Ok anchor
    | None -> timeout_error config watch
  else (
    await_next_frame config watch;
    step_after_frame config watch)

let watch_and_reidentify config () = loop config (make_watch (now_seconds ()))

let run config =
  match EBR.probes ~picture:config.picture [ config.target ] with
  | [] -> Error "In_chamber_reidentifier: eye ROI lies outside game picture"
  | probes -> Effects.with_probes probes (watch_and_reidentify config)
