module S = Plza_story.Steps
module Failure = Engine_run.Failure

let poll_ms = 500
let frame_budget = 20
let agreeing_frames = 3
let ( let* ) = Result.bind

type t = { minimap : string option }

let nothing = { minimap = None }

let to_string s =
  match s.minimap with None -> "nothing read" | Some m -> "minimap " ^ m

let unread ~checkpoint_id ~which detail =
  Failure.cause ~repeats:true "start_signature_unread"
    (Printf.sprintf "%s: its %s signature %s" checkpoint_id which detail)

let other_field ~checkpoint_id ~which key =
  unread ~checkpoint_id ~which
    (Printf.sprintf "has \"%s\": its one field is minimap (a recorded name)" key)

let unrecorded ~checkpoint_id ~which name =
  unread ~checkpoint_id ~which
    ("names minimap " ^ name ^ ", which is not recorded")

let recorded name = List.mem name Plza_readers.Minimap.reference_names

(* One field of the plan's signature. *)
let field ~checkpoint_id ~which (_ : t) = function
  | "minimap", `String name when recorded name -> Ok { minimap = Some name }
  | "minimap", `String name -> Error (unrecorded ~checkpoint_id ~which name)
  | key, _ -> Error (other_field ~checkpoint_id ~which key)

let of_fields ~checkpoint_id ~which fields =
  let* s =
    List.fold_left
      (fun s kv -> Result.bind s (fun s -> field ~checkpoint_id ~which s kv))
      (Ok nothing) fields
  in
  if s = nothing then Error (unread ~checkpoint_id ~which "names nothing")
  else Ok s

(* The plan's [key] signature, [None] when it names none. *)
let signature ~checkpoint_id ~which key (execution : Json_field.obj) =
  match List.assoc_opt key execution with
  | None -> Ok None
  | Some (`Assoc fields) ->
      Result.map Option.some (of_fields ~checkpoint_id ~which fields)
  | Some _ -> Error (unread ~checkpoint_id ~which "is not an object")

(* One frame: nothing when no frame came (as PokemonLZA_AutoStory.cpp reads
   an empty signature), or during a fade or a text box; else the minimap. *)
let read_frame steps =
  let look = steps.S.read_screen () in
  if
    (not look.frame_read) || look.fade_black || look.fade_white
    || look.dialog_box
  then nothing
  else { minimap = look.minimap }

(* The same read on [agreeing_frames] reads in a row, 500 ms apart, within
   [frame_budget] reads; nothing when they never agree. *)
let rec read_agreed steps ~frame ~last ~agreeing =
  if frame >= frame_budget then nothing
  else read_next steps ~frame ~last ~agreeing

and read_next steps ~frame ~last ~agreeing =
  S.wait steps poll_ms;
  let read = read_frame steps in
  let agreeing = if Some read = last then agreeing + 1 else 1 in
  if agreeing >= agreeing_frames && read <> nothing then read
  else read_agreed steps ~frame:(frame + 1) ~last:(Some read) ~agreeing

let read steps = read_agreed steps ~frame:0 ~last:None ~agreeing:0
let confirmed known r = known.minimap = r.minimap

let log_check steps ~checkpoint_id verdict screen =
  steps.S.log
    (Printf.sprintf "[Checkpoint] %s: %s: %s" checkpoint_id verdict screen)

let off_start ~checkpoint_id screen =
  Failure.cause ~repeats:true "chain_off_start"
    (Printf.sprintf "the run is not at %s's start: %s" checkpoint_id screen)

let start_screen r known ~at_end =
  Printf.sprintf "the screen reads (%s), its start is (%s)%s" (to_string r)
    (to_string known)
    (match at_end with
    | Some e -> Printf.sprintf " or its end (%s)" (to_string e)
    | None -> "")

(* The start, or the end: a reload past the checkpoint's own autosave lands
   at its end, and its events skip there (skip_if). *)
let confirm steps ~checkpoint_id known ~at_end =
  let r = read steps in
  let screen = start_screen r known ~at_end in
  if r <> nothing && confirmed known r then
    Ok (log_check steps ~checkpoint_id "START CHECKED" screen)
  else if
    r <> nothing
    && Option.fold ~none:false ~some:(fun e -> confirmed e r) at_end
  then Ok (log_check steps ~checkpoint_id "START CHECKED (at its end)" screen)
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
  let* at_end =
    signature ~checkpoint_id ~which:"end" "end_signature" execution
  in
  match start with
  | None -> Ok (unchecked steps ~checkpoint_id)
  | Some known -> confirm steps ~checkpoint_id known ~at_end

let decode ~checkpoint_id (execution : Json_field.obj) =
  let* (_ : t option) =
    signature ~checkpoint_id ~which:"start" "start_signature" execution
  in
  let* (_ : t option) =
    signature ~checkpoint_id ~which:"end" "end_signature" execution
  in
  Ok ()

let off_end ~checkpoint_id screen =
  Failure.cause "end_off_signature"
    (Printf.sprintf "%s passed its events but did not end at its end: %s"
       checkpoint_id screen)

let check_end steps ~checkpoint_id (execution : Json_field.obj) =
  let* at_end =
    signature ~checkpoint_id ~which:"end" "end_signature" execution
  in
  match at_end with
  | None -> Ok ()
  | Some known ->
      let r = read steps in
      let screen =
        Printf.sprintf "the screen reads (%s), its end is (%s)" (to_string r)
          (to_string known)
      in
      if r <> nothing && confirmed known r then
        Ok (log_check steps ~checkpoint_id "END CHECKED" screen)
      else (
        log_check steps ~checkpoint_id "END CHECK FAILED" screen;
        Error (off_end ~checkpoint_id screen))
