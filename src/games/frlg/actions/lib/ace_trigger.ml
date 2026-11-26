open Frlg_readers
module M = Menu_input
module Text = Frlg_text

type trigger = {
  box3_title : string;
  partner_box : int;
  partner_slot : int option;
}

type game_steps = {
  open_move_pokemon : unit -> unit;
  press : Wire.button -> unit;
  read_title : string list -> string option;
  slot_empty : unit -> bool option;
  ace_at_hand : unit -> bool;
  hand_quick : unit -> bool option;
  await_alive : string -> bool;
  close : unit -> unit;
}

let boxes = 14
let slots = 30
let ace_box = 3
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

(* The box grid: six slots a row, five rows; DOWN from the title lands on
   the top row's third slot. *)
let slots_per_row = 6
let below_title = 2
let presses n b = List.init n (fun _ -> b)

(* From the title to slot [slot] (from 1): DOWN, LEFT or RIGHT across, DOWN
   to its row. *)
let title_to_slot steps slot =
  let col = (slot - 1) mod slots_per_row and row = (slot - 1) / slots_per_row in
  let across = col - below_title in
  steps.press Wire.Down;
  List.iter steps.press
    (presses (abs across) (if across < 0 then Wire.Left else Wire.Right));
  List.iter steps.press (presses row Wire.Down)

(* From slot [slot] UP to the title. *)
let slot_to_title steps slot =
  List.iter steps.press (presses (((slot - 1) / slots_per_row) + 1) Wire.Up)

(* With the hand on the title: [count] boxes from Box 3 to [box], LEFT
   below it and RIGHT above it (pokemon_storage_system_tasks.c
   [INPUT_SCROLL_LEFT], [INPUT_SCROLL_RIGHT]: the box before or after); back
   from [box] to Box 3 with [~back]. Counted, not read: only Box 3's title
   is given, and a carried Pokémon covers the title's left. *)
let scroll_boxes steps ?(back = false) box =
  let ahead = box > ace_box <> back in
  List.iter steps.press
    (presses (abs (box - ace_box)) (if ahead then Wire.Right else Wire.Left))

let quick_on steps =
  if steps.hand_quick () <> Some true then (
    steps.press Wire.Select;
    if steps.hand_quick () <> Some true then
      M.fail "ace_hand_not_quick" "SELECT did not turn the hand orange")

let quick_off steps =
  steps.press Wire.Select;
  if steps.hand_quick () <> Some false then
    M.fail "ace_hand_not_quick" "SELECT did not turn the hand back"

(* From slot [a] to slot [b] of the same box: DOWN or UP to [b]'s row, LEFT
   or RIGHT to its column. *)
let slot_to_slot steps a b =
  let row s = (s - 1) / slots_per_row and col s = (s - 1) mod slots_per_row in
  let down = row b - row a and across = col b - col a in
  List.iter steps.press
    (presses (abs down) (if down < 0 then Wire.Up else Wire.Down));
  List.iter steps.press
    (presses (abs across) (if across < 0 then Wire.Left else Wire.Right))

(* Box 3's first slots are 0x0351 and the empty slot 2. *)
let first_searched box = if box = ace_box then 3 else 1

(* With the hand on slot [slot] of [box]: the first slot from it in reading
   order that holds a Pokémon, the hand left there. *)
let rec first_occupied steps box slot =
  match steps.slot_empty () with
  | Some false -> slot
  | None ->
      M.fail "ace_partner_missing"
        (Printf.sprintf "Box %d slot %d does not read" box slot)
  | Some true when slot = slots ->
      M.fail "ace_partner_missing"
        (Printf.sprintf "Box %d holds no Pokémon" box)
  | Some true ->
      slot_to_slot steps slot (slot + 1);
      first_occupied steps box (slot + 1)

(* With the hand on [box]'s title: to the partner's slot, the one given or
   else the box's first that holds a Pokémon. *)
let find_partner steps t =
  match t.partner_slot with
  | Some slot ->
      title_to_slot steps slot;
      if steps.slot_empty () <> Some false then
        M.fail "ace_partner_missing"
          (Printf.sprintf "Box %d slot %d holds no Pokémon" t.partner_box slot);
      slot
  | None ->
      let first = first_searched t.partner_box in
      title_to_slot steps first;
      first_occupied steps t.partner_box first

(* The partner, any Pokémon in [partner_box] ({!find_partner}), to Box 3
   slot 2, carried in the quick hand (left on); the hand starts on Box 3
   slot 2, which is empty, and ends there. *)
let fetch_partner steps ~log t =
  slot_to_title steps 2;
  scroll_boxes steps t.partner_box;
  let slot = find_partner steps t in
  quick_on steps;
  steps.press Wire.A;
  slot_to_title steps slot;
  scroll_boxes steps ~back:true t.partner_box;
  title_to_slot steps 2;
  steps.press Wire.A;
  steps.press Wire.Up;
  if steps.read_title [ t.box3_title ] = None then
    M.fail "ace_box_not_found"
      ("the partner was put down in a box not titled " ^ quoted t.box3_title);
  title_to_slot steps 2;
  if steps.slot_empty () <> Some false then
    M.fail "ace_partner_missing" "the partner did not land in Box 3 slot 2";
  log
    (Printf.sprintf "PC: the Pokémon in Box %d slot %d moved to Box 3 slot 2."
       t.partner_box slot)

(* Box 3 slot 2 holds the partner (any Pokémon), else it is fetched. *)
let place_partner steps ~log t =
  steps.press Wire.Up;
  scroll_to steps ~toward:Wire.Right t.box3_title boxes;
  title_to_slot steps 2;
  match steps.slot_empty () with
  | Some false -> log "PC: Box 3 slot 2 holds the partner."
  | Some true -> fetch_partner steps ~log t
  | None -> M.fail "ace_partner_missing" "Box 3 slot 2 does not read"

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

(* 0x0351 as frlg.ace_setup leaves it: Ace_mail's check of Box 3 slot 1. *)
let ace_level = 100

let ace_slot : Ace_mail.slot_check =
  {
    box = ace_box;
    slot = 1;
    occupied = true;
    level = Some ace_level;
    male = Some true;
  }

let ace_at_hand () =
  box_reading (fun m ->
      Some (Ace_mail.slot_verdict ace_slot (Ace_mail.box_view m)))
  = Some Ace_mail.As_asked

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
    slot_empty;
    ace_at_hand;
    hand_quick = (fun () -> box_reading Pc_box_screen.hand_quick);
    await_alive = await_alive_after alive_reads;
    close = close ~log;
  }

let in_range ~where ~most name n =
  if n < 1 || n > most then
    Json_field.fail "%s%s is %d, not 1-%d" where name n most;
  n

let int_opt ~where ~most name args =
  if Json_field.has name args then
    Some (in_range ~where ~most name (Json_field.int ~where name args))
  else None

(* Box 3's name: the arg if given, else the run's item's ({!Ace_presets}). *)
let box3_title ~where ~options args =
  if Json_field.has "box3_title" args then
    Json_field.string ~where "box3_title" args
  else
    match Ace_presets.run_item options with
    | Ok (_, item) -> Ace_presets.box_name item ace_box
    | Error e -> Json_field.fail "%sno box3_title, and %s" where e

let decode ~options ~where args =
  let t =
    {
      box3_title = box3_title ~where ~options args;
      partner_box =
        Option.value ~default:1 (int_opt ~where ~most:boxes "partner_box" args);
      partner_slot = int_opt ~where ~most:slots "partner_slot" args;
    }
  in
  if t.partner_box = ace_box && t.partner_slot = Some 1 then
    Json_field.fail "%sBox 3 slot 1 is 0x0351, not a partner" where;
  t

let ace_trigger ~log ~options (_ : Pokemon_engine.Plan.event) args =
  Result.bind
    (Action_args.decode ~action:"ace_trigger" (decode ~options) args)
    (fun t -> M.run (fun () -> run (screen_game_steps ~log) ~log t))

let handlers ~log ~options = [ ("ace_trigger", ace_trigger ~log ~options) ]
