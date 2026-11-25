module Failure = Engine_run.Failure

type verdict = Walk_on | Ended | Failed of Failure.cause

(* Busy reads in a row that are a scene taking control. *)
let scene_reads_to_stop = 2

let passed_on_the_way walk held_ms earliest_end_ms =
  Printf.sprintf
    "[PLZA] %s: the end event after %d ms of the last leg, before its %d ms: \
     passed on the way, on."
    walk held_ms earliest_end_ms

let ended walk held_ms =
  Printf.sprintf "[PLZA] %s: the end event after %d ms of the last leg." walk
    held_ms

let ended_on walk screen =
  Printf.sprintf "[PLZA] %s: ended on: %s" walk (Walk_screen.describe screen)

let black_fade walk held_ms =
  Printf.sprintf
    "[PLZA] %s: a black fade after %d ms of the last leg: the scene takes over."
    walk held_ms

let scene_took walk what held_ms =
  Printf.sprintf
    "[PLZA] %s: a scene (%s) took control after %d ms of the last leg: the \
     walk stops."
    walk what held_ms

let prompt_went walk held_ms =
  Printf.sprintf
    "[PLZA] %s: the A prompt after %d ms of the last leg went again: on." walk
    held_ms

let check_end_event ~log ~log_detail ~prompt_steady walk event ~earliest_end_ms
    (screen : Walk_screen.t) ~held_ms =
  let shows = Walk_screen.shows event screen in
  if shows && held_ms < earliest_end_ms then (
    log (passed_on_the_way walk held_ms earliest_end_ms);
    Walk_on)
  else if shows && event = Plza_rules.Walk_args.Prompt && not (prompt_steady ())
  then (
    log (prompt_went walk held_ms);
    Walk_on)
  else if shows then (
    log (ended walk held_ms);
    log_detail (ended_on walk screen);
    Ended)
  else if screen.fade_black then (
    log (black_fade walk held_ms);
    Ended)
  else Walk_on

let check_scene log walk =
  let busy_reads = ref 0 in
  fun screen ~held_ms ->
    let busy = Walk_screen.busy_with screen in
    busy_reads := if busy = None then 0 else !busy_reads + 1;
    match busy with
    | Some what when !busy_reads >= scene_reads_to_stop ->
        log (scene_took walk what held_ms);
        Ended
    | _ -> Walk_on

let no_scene walk elapsed_ms =
  Printf.sprintf
    "%s: control still free after %d ms of the last leg: no scene took it" walk
    elapsed_ms

let no_end_event walk elapsed_ms =
  Printf.sprintf "%s: no end event within %d ms of the last leg" walk elapsed_ms

let timed_out walk (until : Plza_rules.Walk_args.until) ~elapsed_ms =
  match until with
  | Scene -> Failure.cause "walk_no_scene" (no_scene walk elapsed_ms)
  | Event _ | Talk _ ->
      Failure.cause "walk_no_end" (no_end_event walk elapsed_ms)
