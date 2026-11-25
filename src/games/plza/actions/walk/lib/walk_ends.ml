module Failure = Engine_run.Failure

(* Busy looks in a row that are a scene taking control. *)
let scene_looks_to_stop = 2

let passed_on_the_way walk held end_after_ms =
  Printf.sprintf
    "[PLZA] %s: the end event after %d ms of the last leg, before its %d ms: \
     passed on the way, on."
    walk held end_after_ms

let ended walk held =
  Printf.sprintf "[PLZA] %s: the end event after %d ms of the last leg." walk
    held

let ended_on walk look =
  Printf.sprintf "[PLZA] %s: ended on: %s" walk (Walk_look.events look)

let black_fade walk held =
  Printf.sprintf
    "[PLZA] %s: a black fade after %d ms of the last leg: the scene takes over."
    walk held

let scene_took walk what held =
  Printf.sprintf
    "[PLZA] %s: a scene (%s) took control after %d ms of the last leg: the \
     walk stops."
    walk what held

let end_event_look ~log ~log_detail walk event ~end_after_ms
    (look : Walk_look.t) held =
  let shows = Walk_look.shows event look in
  if shows && held < end_after_ms then (
    log (passed_on_the_way walk held end_after_ms);
    None)
  else if shows then (
    log (ended walk held);
    log_detail (ended_on walk look);
    Some (Ok ()))
  else if look.fade_black then (
    log (black_fade walk held);
    Some (Ok ()))
  else None

let scene_look log walk =
  let scene_looks = ref 0 in
  fun look held ->
    let busy = Walk_look.not_free_control look in
    scene_looks := if busy = None then 0 else !scene_looks + 1;
    match busy with
    | Some what when !scene_looks >= scene_looks_to_stop ->
        log (scene_took walk what held);
        Some (Ok ())
    | _ -> None

let no_scene walk elapsed =
  Printf.sprintf
    "%s: control still free after %d ms of the last leg: no scene took it" walk
    elapsed

let no_end_event walk elapsed =
  Printf.sprintf "%s: no end event within %d ms of the last leg" walk elapsed

let no_end walk (until : Plza_terms.Walk_args.until) elapsed =
  match until with
  | Scene -> Failure.cause "walk_no_scene" (no_scene walk elapsed)
  | Event _ -> Failure.cause "walk_no_end" (no_end_event walk elapsed)
