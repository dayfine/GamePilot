module S = Plza_story.Story_steps
module Failure = Engine_run.Failure

let poll_ms = 500
let frame_budget = 20
let agreeing_frames = 3
let ( let* ) = Result.bind

(* The minimap a signature names; a signature naming anything else is
   refused, as no reader here reads it. [which] is "start" or "end". *)
let named_minimap ~checkpoint_id ~which fields =
  let refuse detail =
    Error
      (Failure.cause ~repeats:true "start_signature_unread"
         (Printf.sprintf "%s: its %s signature %s" checkpoint_id which detail))
  in
  match fields with
  | [ ("minimap", `String name) ] ->
      if List.mem name Plza_readers.Minimap.reference_names then Ok name
      else refuse ("names minimap " ^ name ^ ", which is not recorded")
  | _ ->
      refuse
        "is not one minimap ({\"minimap\": \"<name>\"}): only the minimap is \
         read here"

let not_an_object ~checkpoint_id ~which =
  Failure.cause ~repeats:true "start_signature_unread"
    (Printf.sprintf "%s: its %s signature is not an object" checkpoint_id which)

(* The plan's [key] signature's minimap, [None] when it names none. *)
let signature ~checkpoint_id ~which key (execution : Json_field.obj) =
  match List.assoc_opt key execution with
  | None -> Ok None
  | Some (`Assoc fields) ->
      Result.map Option.some (named_minimap ~checkpoint_id ~which fields)
  | Some _ -> Error (not_an_object ~checkpoint_id ~which)

(* The minimap read on [agreeing_frames] reads in a row, 500 ms apart, within
   [frame_budget] reads; [None] when they never agree on one. *)
let rec read_agreed steps ~frame ~last ~agreeing =
  if frame >= frame_budget then None
  else (
    S.wait steps poll_ms;
    let read = (steps.S.read_screen ()).minimap in
    let agreeing = if read = last then agreeing + 1 else 1 in
    match read with
    | Some name when agreeing >= agreeing_frames -> Some name
    | _ -> read_agreed steps ~frame:(frame + 1) ~last:read ~agreeing)

let shown = function Some name -> "minimap " ^ name | None -> "no minimap"

let log_check steps ~checkpoint_id verdict screen =
  steps.S.log
    (Printf.sprintf "[Checkpoint] %s: %s: %s" checkpoint_id verdict screen)

let off_start ~checkpoint_id screen =
  Failure.cause ~repeats:true "chain_off_start"
    (Printf.sprintf "the run is not at %s's start: %s" checkpoint_id screen)

let start_screen read name ~end_name =
  Printf.sprintf "the screen reads (%s), its start is (minimap %s)%s"
    (shown read) name
    (match end_name with
    | Some e -> Printf.sprintf " or its end (minimap %s)" e
    | None -> "")

(* The start's minimap, or the end's: a reload past the checkpoint's own
   autosave lands at its end, and its events skip there (skip_if). *)
let confirm steps ~checkpoint_id name ~end_name =
  let read = read_agreed steps ~frame:0 ~last:None ~agreeing:0 in
  let screen = start_screen read name ~end_name in
  if read = Some name then
    Ok (log_check steps ~checkpoint_id "START CHECKED" screen)
  else if read <> None && read = end_name then
    Ok (log_check steps ~checkpoint_id "START CHECKED (at its end)" screen)
  else (
    log_check steps ~checkpoint_id "START CHECK FAILED" screen;
    Error (off_start ~checkpoint_id screen))

let unchecked steps ~checkpoint_id =
  steps.S.log
    (Printf.sprintf
       "[Checkpoint] %s: START UNCHECKED: its plan names no start signature"
       checkpoint_id)

let check steps ~checkpoint_id (execution : Json_field.obj) =
  let* start =
    signature ~checkpoint_id ~which:"start" "start_signature" execution
  in
  let* end_name =
    signature ~checkpoint_id ~which:"end" "end_signature" execution
  in
  match start with
  | None -> Ok (unchecked steps ~checkpoint_id)
  | Some name -> confirm steps ~checkpoint_id name ~end_name

let off_end ~checkpoint_id screen =
  Failure.cause "end_off_signature"
    (Printf.sprintf "%s passed its events but did not end at its end: %s"
       checkpoint_id screen)

let check_end steps ~checkpoint_id (execution : Json_field.obj) =
  let* end_name =
    signature ~checkpoint_id ~which:"end" "end_signature" execution
  in
  match end_name with
  | None -> Ok ()
  | Some name ->
      let read = read_agreed steps ~frame:0 ~last:None ~agreeing:0 in
      let screen =
        Printf.sprintf "the screen reads (%s), its end is (minimap %s)"
          (shown read) name
      in
      if read = Some name then
        Ok (log_check steps ~checkpoint_id "END CHECKED" screen)
      else (
        log_check steps ~checkpoint_id "END CHECK FAILED" screen;
        Error (off_end ~checkpoint_id screen))
