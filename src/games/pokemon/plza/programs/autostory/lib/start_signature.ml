module S = Plza_story.Story_steps
module Failure = Engine_run.Failure

let poll_ms = 500
let frame_budget = 20
let agreeing_frames = 3
let ( let* ) = Result.bind

(* The minimap the plan's start names; a signature naming anything else is
   refused, as no reader here reads it. *)
let named_minimap ~checkpoint_id fields =
  let refuse detail =
    Error
      (Failure.cause ~repeats:true "start_signature_unread"
         (checkpoint_id ^ ": its start signature " ^ detail))
  in
  match fields with
  | [ ("minimap", `String name) ] ->
      if List.mem name Plza_readers.Minimap.reference_names then Ok name
      else refuse ("names minimap " ^ name ^ ", which is not recorded")
  | _ ->
      refuse
        "is not one minimap ({\"minimap\": \"<name>\"}): only the minimap is \
         read here"

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

let confirm steps ~checkpoint_id name =
  let read = read_agreed steps ~frame:0 ~last:None ~agreeing:0 in
  let screen =
    Printf.sprintf "the screen reads (%s), its start is (minimap %s)"
      (shown read) name
  in
  if read = Some name then
    Ok (log_check steps ~checkpoint_id "START CHECKED" screen)
  else (
    log_check steps ~checkpoint_id "START CHECK FAILED" screen;
    Error (off_start ~checkpoint_id screen))

let unchecked steps ~checkpoint_id =
  steps.S.log
    (Printf.sprintf
       "[Checkpoint] %s: START UNCHECKED: its plan names no start signature"
       checkpoint_id)

let not_an_object ~checkpoint_id =
  Failure.cause ~repeats:true "start_signature_unread"
    (checkpoint_id ^ ": its start signature is not an object")

let check steps ~checkpoint_id (execution : Json_field.obj) =
  match List.assoc_opt "start_signature" execution with
  | None -> Ok (unchecked steps ~checkpoint_id)
  | Some (`Assoc fields) ->
      let* name = named_minimap ~checkpoint_id fields in
      confirm steps ~checkpoint_id name
  | Some _ -> Error (not_an_object ~checkpoint_id)
