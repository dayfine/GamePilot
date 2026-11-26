open Frlg_readers
module M = Menu_input
module Text = Frlg_text

type trigger = { box1_title : string; box3_title : string; partner : string }

type game_steps = {
  open_move_pokemon : unit -> unit;
  press : Wire.button -> unit;
  read_title : string list -> string option;
  species_at_hand : unit -> string option;
  slot_empty : unit -> bool option;
  ace_at_hand : unit -> bool;
  hand_quick : unit -> bool option;
  await_alive : string -> bool;
  close : unit -> unit;
}

let boxes = 14
let alive_timeout_ms = 3000
let quoted s = "\"" ^ s ^ "\""

(* With the hand on the title: [toward] (LEFT or RIGHT) until it reads
   [name]. *)
let rec scroll_to steps ~toward name tries =
  match steps.read_title [ name ] with
  | Some _ -> ()
  | None when tries = 0 ->
      M.fail "ace_box_not_found" ("no box title reads " ^ quoted name)
  | None ->
      steps.press toward;
      scroll_to steps ~toward name (tries - 1)

let down_to_slot steps slot =
  steps.press Wire.Down;
  List.iter steps.press (List.init (3 - slot) (fun _ -> Wire.Left))

(* From a slot of the top row to the box named [name], the hand on its slot
   [slot] (1 or 2): UP to the title, scroll, DOWN onto the third slot, LEFT
   to the slot. *)
let to_slot steps ~toward name slot =
  steps.press Wire.Up;
  scroll_to steps ~toward name boxes;
  down_to_slot steps slot

(* Box 1 to Box 3: two RIGHTs on the title (pokemon_storage_system_tasks.c
   [INPUT_SCROLL_RIGHT]: the next box). Counted, not read: the Pokémon the
   hand carries covers the title's left. *)
let box1_to_box3 = 2

let quick_on steps =
  if steps.hand_quick () <> Some true then (
    steps.press Wire.Select;
    if steps.hand_quick () <> Some true then
      M.fail "ace_hand_not_quick" "SELECT did not turn the hand orange")

let quick_off steps =
  steps.press Wire.Select;
  if steps.hand_quick () <> Some false then
    M.fail "ace_hand_not_quick" "SELECT did not turn the hand back"

(* The partner from Box 1 slot 1 to Box 3 slot 2, carried in the quick hand
   (left on); the hand starts on Box 3 slot 2, which is empty, and ends
   there. *)
let fetch_partner steps ~log t =
  to_slot steps ~toward:Wire.Left t.box1_title 1;
  if steps.species_at_hand () <> Some t.partner then
    M.fail "ace_partner_missing"
      (Printf.sprintf "Box 1 slot 1 does not hold %s" t.partner);
  quick_on steps;
  steps.press Wire.A;
  steps.press Wire.Up;
  List.iter steps.press (List.init box1_to_box3 (fun _ -> Wire.Right));
  down_to_slot steps 2;
  steps.press Wire.A;
  steps.press Wire.Up;
  if steps.read_title [ t.box3_title ] = None then
    M.fail "ace_box_not_found"
      ("the partner was put down in a box not titled " ^ quoted t.box3_title);
  down_to_slot steps 2;
  if steps.species_at_hand () <> Some t.partner then
    M.fail "ace_partner_missing"
      (Printf.sprintf "%s did not land in Box 3 slot 2" t.partner);
  log (Printf.sprintf "PC: %s moved to Box 3 slot 2." t.partner)

let place_partner steps ~log t =
  to_slot steps ~toward:Wire.Right t.box3_title 2;
  match steps.species_at_hand () with
  | Some s when s = t.partner ->
      log (Printf.sprintf "PC: %s is in Box 3 slot 2." t.partner)
  | Some s -> M.fail "ace_slot_taken" (Printf.sprintf "Box 3 slot 2 holds %s" s)
  | None when steps.slot_empty () = Some true -> fetch_partner steps ~log t
  | None -> M.fail "ace_slot_taken" "Box 3 slot 2 is not empty"

(* From Box 3 slot 2: LEFT onto 0x0351, the quick hand (read on the first
   slot only), pick it up, shift it with the partner twice (the second runs
   the code), put it back, the hand back to normal. *)
let swap_twice steps ~log =
  steps.press Wire.Left;
  if not (steps.ace_at_hand ()) then
    M.fail "ace_not_in_slot" "Box 3 slot 1 does not show species 0x0351";
  quick_on steps;
  steps.press Wire.A;
  steps.press Wire.Right;
  steps.press Wire.A;
  steps.press Wire.A;
  log "PC: 0x0351 shifted with the partner twice.";
  steps.press Wire.Left;
  steps.press Wire.A;
  quick_off steps

let run steps ~log t =
  steps.open_move_pokemon ();
  place_partner steps ~log t;
  swap_twice steps ~log;
  steps.press Wire.Up;
  if not (steps.await_alive t.box3_title) then
    M.fail "ace_game_stopped" "the box title does not read after the swaps";
  log "PC: the box screen still answers.";
  steps.close ()

(* The game's steps. Presses and waits measured on mGBA (2026-11-25): a
   box scroll takes about 50 frames, a shift about 40. *)
let hold_ms = 100
let hand_ms = 500
let scroll_ms = 1200
let shift_ms = 1200
let look_timeout_ms = 1000

let press_wait ms b =
  ignore (Effects.submit [ M.hold ~hold_ms ~cooldown_ms:ms b ])

let press b =
  match b with
  | Wire.Right | Wire.Left -> press_wait scroll_ms b
  | Wire.A -> press_wait shift_ms b
  | _ -> press_wait hand_ms b

let box_reading f =
  Effects.with_probes Pc_box_screen.probes (fun () ->
      match Effects.await ~timeout_ms:look_timeout_ms (fun _ -> true) with
      | Holds m -> f m
      | Timeout -> None)

let read_title candidates =
  match Text.Box_title.read (Text_data.glyphs ()) candidates with
  | Ok (Read { text; _ }) -> Some text
  | Ok (No_match _) | Error _ -> None

let ace_level = "100"

let level_reads () =
  match
    Text.Line_reading.read ~ink:Text.Line_reading.light_ink
      (Text_data.glyphs ()) Text.Text_lines.pc_data_level [ ace_level ]
  with
  | Read _ -> true
  | No_match _ -> false

let ace_at_hand () =
  box_reading (fun m ->
      Some
        (Pc_box_screen.panel_occupied m = Some true
        && Pc_box_screen.male m = Some true))
  = Some true
  && level_reads ()

let alive_reads = alive_timeout_ms / look_timeout_ms

let rec await_alive_after tries name =
  read_title [ name ] = Some name
  || (tries > 0 && await_alive_after (tries - 1) name)

let open_move_pokemon ~log () =
  Effects.with_probes Pc_screen.probes (fun () ->
      Pc_box.to_box_screen ~log Pc_box.screen_game_steps)

let close ~log () =
  Effects.with_probes Pc_screen.probes (fun () ->
      Pc_box.leave ~log Pc_box.screen_game_steps)

let slot_empty () =
  box_reading (fun m -> Option.map not (Pc_box_screen.panel_occupied m))

let screen_game_steps ~log =
  {
    open_move_pokemon = open_move_pokemon ~log;
    press;
    read_title;
    species_at_hand = Pc_deposit.species_shown;
    slot_empty;
    ace_at_hand;
    hand_quick = (fun () -> box_reading Pc_box_screen.hand_quick);
    await_alive = await_alive_after alive_reads;
    close = close ~log;
  }

let decode ~where args =
  {
    box1_title = Json_field.string ~where "box1_title" args;
    box3_title = Json_field.string ~where "box3_title" args;
    partner = Json_field.string ~where "partner" args;
  }

let ace_trigger ~log (_ : Pokemon_engine.Plan.event) args =
  Result.bind (Action_args.decode ~action:"ace_trigger" decode args) (fun t ->
      M.run (fun () -> run (screen_game_steps ~log) ~log t))

let handlers ~log = [ ("ace_trigger", ace_trigger ~log) ]
