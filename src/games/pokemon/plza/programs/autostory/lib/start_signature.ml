module S = Plza_story.Steps
module Failure = Engine_run.Failure

let poll_ms = 500
let frame_budget = 20
let agreeing_frames = 3
let ( let* ) = Result.bind

module Sig = Plza_rules.Screen_signature

type t = Sig.t = {
  talk_prompt : bool option;
  wild_zone : bool option;
  near_rocks : bool option;
  party : int option;
  minimap : string option;
}

let nothing = Sig.nothing
let to_string = Sig.to_string

let unread ~checkpoint_id ~which detail =
  Failure.cause ~repeats:true "start_signature_unread"
    (Printf.sprintf "%s: its %s signature %s" checkpoint_id which detail)

let unrecorded ~checkpoint_id ~which name =
  unread ~checkpoint_id ~which
    ("names minimap " ^ name ^ ", which is not recorded")

let recorded name = List.mem name Plza_readers.Minimap.reference_names

(* A signature as the plan writes it, its minimap a recorded one. *)
let of_plan ~checkpoint_id ~which value =
  match Plza_plan_format.signature_of_plan value with
  | Error detail -> Error (unread ~checkpoint_id ~which detail)
  | Ok { minimap = Some name; _ } when not (recorded name) ->
      Error (unrecorded ~checkpoint_id ~which name)
  | Ok s -> Ok s

(* The plan's start signature, [None] when it names none. *)
let start_signature ~checkpoint_id (execution : Json_field.obj) =
  match List.assoc_opt "start_signature" execution with
  | None -> Ok None
  | Some value ->
      Result.map Option.some (of_plan ~checkpoint_id ~which:"start" value)

(* One frame: nothing when no frame came (as PokemonLZA_AutoStory.cpp reads
   an empty signature), or during a fade or a text box; else the A prompt,
   the party count and the minimap. *)
let read_frame steps =
  let look = steps.S.read_screen () in
  if
    (not look.frame_read) || look.fade_black || look.fade_white
    || look.dialog_box
  then nothing
  else
    {
      talk_prompt = Some look.interact_prompt;
      wild_zone = None;
      near_rocks = None;
      party = steps.S.read_party_slots ();
      minimap = look.minimap;
    }

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

type pin_fields = { in_zone : bool; at_rocks : bool }
(** The fields the map's pin answers that a signature names. *)

let names_pin s =
  {
    in_zone = Option.is_some s.wild_zone;
    at_rocks = Option.is_some s.near_rocks;
  }

let either a b =
  { in_zone = a.in_zone || b.in_zone; at_rocks = a.at_rocks || b.at_rocks }

(* With a signature naming the wild zone or the rocks, also the map's pin (as
   PokemonLZA_AutoStory.cpp reads the start position): in Wild Zone 1 or not,
   near Taunie's rocks or not. *)
let read steps (asked : pin_fields) =
  let r = read_agreed steps ~frame:0 ~last:None ~agreeing:0 in
  if (asked.in_zone || asked.at_rocks) && r <> nothing then
    let pin = Plza_walk.Map_walk.read_pin (S.walk_game_steps steps) in
    let answer yes f = if yes then Option.map f pin else None in
    {
      r with
      wild_zone = answer asked.in_zone Plza_walk.Wild_zone_one.pin_in_zone;
      near_rocks = answer asked.at_rocks Plza_walk.Wild_zone_one.near_rocks;
    }
  else r

let confirmed known r = Sig.confirmed ~known r

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
   at its end, where the runner runs none of its events. *)
let confirm steps ~checkpoint_id known ~at_end =
  let asked =
    Option.fold ~none:(names_pin known)
      ~some:(fun e -> either (names_pin known) (names_pin e))
      at_end
  in
  let r = read steps asked in
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

let check steps ~checkpoint_id ~at_end (execution : Json_field.obj) =
  let* start = start_signature ~checkpoint_id execution in
  match start with
  | None -> Ok (unchecked steps ~checkpoint_id)
  | Some known -> confirm steps ~checkpoint_id known ~at_end

let decode ~checkpoint_id (plan : Plza_engine.Plan.t) =
  let* (_ : t option) = start_signature ~checkpoint_id plan.execution in
  match Option.bind plan.postconditions (fun p -> p.place) with
  | Some { minimap = Some name; _ } when not (recorded name) ->
      Error (unrecorded ~checkpoint_id ~which:"end" name)
  | _ -> Ok ()

(* The next checkpoint's start signature, as an end place. *)
let next_start = function
  | None -> Ok None
  | Some (next : Plza_engine.Plan.t) ->
      start_signature ~checkpoint_id:next.checkpoint.checkpoint_id
        next.execution

let promised_end ~next (plan : Plza_engine.Plan.t) =
  let own = Option.bind plan.postconditions (fun p -> p.place) in
  let flags =
    Option.fold ~none:[]
      ~some:(fun (p : Plza_rules.Postconditions.t) -> p.flags)
      plan.postconditions
  in
  let* place = if Option.is_some own then Ok own else next_start next in
  Ok { Plza_rules.Postconditions.place; flags }

let read_place steps ~checkpoint_id (place : t) =
  let r = read steps (names_pin place) in
  log_check steps ~checkpoint_id "END PLACE READ"
    (Printf.sprintf "the screen reads (%s), its end is (%s)" (to_string r)
       (to_string place));
  r

let read_end steps ~checkpoint_id (p : Plza_rules.Postconditions.t) :
    Plza_rules.Postconditions.reads =
  {
    screen =
      Option.fold ~none:nothing ~some:(read_place steps ~checkpoint_id) p.place;
    flags_read = Story_flag_read.read steps ~checkpoint_id p.flags;
  }
