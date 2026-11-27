type timings = {
  ready_seconds : float;
  guard_seconds : float;
  max_wait_seconds : float;
}

let default_timings =
  { ready_seconds = 5.0; guard_seconds = 0.30; max_wait_seconds = 20.0 }

type t = {
  span : int;
  confirm_seconds : float;
  events_before_confirm : int;
  gap_margin_seconds : float;
}

let max_pokemon_interval =
  Blink_model.pokemon_blink_max_seconds
  +. Blink_model.pokemon_blink_offset_seconds

let validate_timings timings =
  if timings.ready_seconds < 0.0 then
    Error "Static_press_schedule: ready_seconds must be non-negative"
  else if timings.guard_seconds < 0.0 then
    Error "Static_press_schedule: guard_seconds must be non-negative"
  else if timings.max_wait_seconds < timings.ready_seconds then
    Error "Static_press_schedule: max_wait_seconds must be >= ready_seconds"
  else Ok ()

let try_gap ~context ~timings ~events_before (prev : Static_timeline.event)
    (next : Static_timeline.event) =
  let midpoint = (prev.time_seconds +. next.time_seconds) /. 2.0 in
  let confirm =
    Float.max midpoint (timings.ready_seconds +. timings.guard_seconds)
  in
  let left_margin = confirm -. prev.time_seconds in
  let right_margin = next.time_seconds -. confirm in
  if
    confirm >= timings.ready_seconds
    && confirm <= timings.max_wait_seconds
    && left_margin >= timings.guard_seconds
    && right_margin >= timings.guard_seconds
  then
    Some
      {
        span =
          context.Static_timeline.advance_delay + events_before
          + context.advances_after_accept;
        confirm_seconds = confirm;
        events_before_confirm = events_before;
        gap_margin_seconds = Float.min left_margin right_margin;
      }
  else None

let rec scan_gaps ~context ~timings index = function
  | prev :: (next :: _ as rest) -> (
      match try_gap ~context ~timings ~events_before:(index + 1) prev next with
      | Some found -> Ok found
      | None -> scan_gaps ~context ~timings (index + 1) rest)
  | [ _ ] | [] ->
      Error "No blink-free gap met the guard margin before max_wait_seconds."

let run_timeline ~context ~timings state =
  let horizon =
    timings.max_wait_seconds +. context.Static_timeline.tick_seconds
    +. max_pokemon_interval
  in
  Result.bind
    (Static_timeline.simulate_timeline state ~context ~duration_seconds:horizon)
    (scan_gaps ~context ~timings 0)

let schedule_timeline ~context ~timings state =
  Result.bind (validate_timings timings) (fun () ->
      run_timeline ~context ~timings state)

let direct_schedule (context : Static_timeline.context) =
  Ok
    {
      span = context.advance_delay + context.advances_after_accept;
      confirm_seconds = 0.0;
      events_before_confirm = 0;
      gap_margin_seconds = 0.0;
    }

let schedule ~trigger_kind ~(context : Static_timeline.context) ~timings state =
  match trigger_kind with
  | Static_targets.Direct_no_pokemon_model -> direct_schedule context
  | Static_targets.Timeline_single_confirm ->
      schedule_timeline ~context ~timings state
