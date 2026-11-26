open Blink_extraction

type reanchored = {
  clock : Advance_clock.t;
  drift_seconds : float;
  drift_advances : float;
}

type failure = Too_few_blinks | Shared_tick | Not_reidentified of string

(* The newest [count] blinks of the anchor watcher. *)
let newest_run streams ~anchor_stream ~count =
  match List.nth_opt streams anchor_stream with
  | Some stream when count >= 2 && List.length stream >= count ->
      Ok
        (List.filteri
           (fun index _ -> index >= List.length stream - count)
           stream)
  | _ -> Error Too_few_blinks

(* [std::llround] of a gap in ticks; under one means two events on one tick. *)
let gap_ticks (earlier : blink_event) (later : blink_event) ~tick_seconds =
  let ticks =
    int_of_float
      (Float.round ((later.seconds -. earlier.seconds) /. tick_seconds))
  in
  if ticks < 1 then Error Shared_tick else Ok ticks

let intervals run ~tick_seconds =
  let rec gaps found = function
    | earlier :: (later :: _ as rest) -> (
        match gap_ticks earlier later ~tick_seconds with
        | Ok ticks -> gaps (ticks :: found) rest
        | Error _ as shared -> shared)
    | _ -> Ok (List.rev found)
  in
  gaps [] run

let reidentify (config : Blink_recovery.config)
    (recovery : Blink_recovery.recovery) (clock : Advance_clock.t) ~first_time
    intervals =
  let estimate = Advance_clock.advance_at clock first_time in
  let radius = config.reanchor_search_radius in
  State_reidentifier.reidentify_advances
    {
      base_state = recovery.state;
      search_min = (if estimate > radius then estimate - radius else 0);
      search_max = estimate + radius;
      npcs = clock.npcs;
      observation = Intervals intervals;
    }

let moved (clock : Advance_clock.t) ~last_time advances =
  let drift_seconds =
    Advance_clock.seconds_between
      ~earlier:(Advance_clock.time_of_advance clock advances)
      last_time
  in
  let seconds_per_advance =
    if clock.npcs = 0 then clock.tick_seconds
    else clock.tick_seconds /. float_of_int clock.npcs
  in
  {
    clock = { clock with anchor_advance = advances; anchor_time = last_time };
    drift_seconds;
    drift_advances = drift_seconds /. seconds_per_advance;
  }

let reanchor_absolute (config : Blink_recovery.config)
    (recovery : Blink_recovery.recovery) streams ~origin
    (clock : Advance_clock.t) =
  let ( let* ) = Result.bind in
  let* run =
    newest_run streams ~anchor_stream:recovery.anchor_stream
      ~count:config.reanchor_blinks
  in
  let* intervals = intervals run ~tick_seconds:clock.tick_seconds in
  let first : blink_event = List.hd run in
  let last : blink_event = List.nth run (List.length run - 1) in
  let result =
    reidentify config recovery clock
      ~first_time:(Advance_clock.plus_seconds origin first.seconds)
      intervals
  in
  if result.success then
    Ok
      (moved clock
         ~last_time:(Advance_clock.plus_seconds origin last.seconds)
         result.advances_to_last_blink)
  else Error (Not_reidentified result.failure_reason)
