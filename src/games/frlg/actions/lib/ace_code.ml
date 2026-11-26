module M = Menu_input
module P = Ace_presets

type game_steps = {
  open_move_pokemon : unit -> unit;
  press : Wire.button -> unit;
  read_title : string list -> string option;
  slot_empty : unit -> bool option;
  ace_at_hand : unit -> bool;
  name_title : others:string list -> string -> unit;
  close : unit -> unit;
}

let box_numbers = List.init P.boxes (fun i -> i + 1)

let from_slot first =
  List.init (Ace_trigger.slots - first + 1) (fun i -> first + i)

(* pomeg's FRLG FAQ: Box 13 from slot 7, and Box 14. *)
let names_box = 13
let first_named_slot = 7

let empty_slots =
  [ (names_box, from_slot first_named_slot); (names_box + 1, from_slot 1) ]

let quoted s = "\"" ^ s ^ "\""
let presses n b = List.init (max 0 n) (fun _ -> b)

let all_names t =
  List.sort_uniq compare (List.concat_map (P.known_names t) box_numbers)

(* The title as box [b]'s: [None] when it reads no name; fails when it reads
   only another box's. *)
let title_of steps t b =
  match steps.read_title (all_names t) with
  | Some name when not (List.mem name (P.known_names t b)) ->
      M.fail "ace_box_lost"
        (Printf.sprintf "Box %d's title reads %s, another box's name" b
           (quoted name))
  | read -> read

let rec to_box1 steps t tries =
  match steps.read_title (all_names t) with
  | Some name when List.mem name (P.known_names t 1) -> ()
  | _ when tries = 0 -> M.fail "ace_box_lost" "no box title reads as Box 1"
  | _ ->
      steps.press Wire.Right;
      to_box1 steps t (tries - 1)

(* With the hand on the title: the box screen opened, the title shown, Box 1
   found. *)
let open_at_box1 steps t =
  steps.open_move_pokemon ();
  steps.press Wire.Up;
  to_box1 steps t P.boxes

(* A title that reads as box [b - 1]'s and not [b]'s: the scroll was lost. *)
let still_before t b name =
  let before = if b = 1 then P.boxes else b - 1 in
  List.mem name (P.known_names t before)
  && not (List.mem name (P.known_names t b))

let scroll_tries = 3

(* With the hand on box [b - 1]'s title: RIGHT to box [b]'s, pressed again
   while the title still reads as the box before (a RIGHT the screen dropped
   on mGBA, right after a rename). *)
let rec next_box steps t b tries =
  steps.press Wire.Right;
  match steps.read_title (all_names t) with
  | Some name when still_before t b name ->
      if tries = 0 then
        M.fail "ace_box_lost" (Printf.sprintf "RIGHT did not reach Box %d" b);
      next_box steps t b (tries - 1)
  | _ -> ()

(* From box [from]'s title RIGHT to box [to_]'s, which must read. *)
let scroll steps t ~from to_ =
  List.iter
    (fun b -> next_box steps t b scroll_tries)
    (List.init (to_ - from) (fun i -> from + i + 1));
  if title_of steps t to_ = None then
    M.fail "ace_box_lost" (Printf.sprintf "Box %d's title does not read" to_)

(* On Box 14's title: RIGHT wraps to Box 1, whose title must read [box1]
   (any of its names when [None]): the count of boxes held, though Boxes 12
   to 14 share a name. *)
let wrap_to_box1 steps t box1 =
  next_box steps t 1 scroll_tries;
  let ok =
    match (steps.read_title (all_names t), box1) with
    | Some name, Some want -> name = want
    | Some name, None -> List.mem name (P.known_names t 1)
    | None, _ -> false
  in
  if not ok then
    M.fail "ace_box_lost" "RIGHT from what was counted as Box 14 is not Box 1"

(* The box grid: six slots a row; DOWN from the title lands on the top row's
   third slot (Ace_trigger). *)
let per_row = 6
let below_title = 3
let row s = (s - 1) / per_row
let col s = (s - 1) mod per_row

let hand_to steps ~from to_ =
  let down = row to_ - row from and across = col to_ - col from in
  List.iter steps.press (presses down Wire.Down);
  List.iter steps.press (presses (-down) Wire.Up);
  List.iter steps.press (presses across Wire.Right);
  List.iter steps.press (presses (-across) Wire.Left)

let from_title steps slot =
  steps.press Wire.Down;
  hand_to steps ~from:below_title slot

let to_title steps slot = List.iter steps.press (presses (row slot + 1) Wire.Up)

let check_empty_slot steps b s =
  let where = Printf.sprintf "Box %d slot %d" b s in
  match steps.slot_empty () with
  | Some true -> ()
  | Some false -> M.fail "ace_box_not_empty" (where ^ " holds a Pokémon")
  | None -> M.fail "ace_box_not_empty" (where ^ " does not read")

(* With the hand on box [b]'s title: each slot visited and read, back up to
   the title. *)
let check_empty steps ~log b slots =
  steps.press Wire.Down;
  let last =
    List.fold_left
      (fun at s ->
        hand_to steps ~from:at s;
        check_empty_slot steps b s;
        s)
      below_title slots
  in
  to_title steps last;
  log
    (Printf.sprintf "PC: Box %d slots %d-%d empty." b (List.hd slots)
       (List.nth slots (List.length slots - 1)))

let ace_box = 3

let check_ace steps ~log t =
  scroll steps t ~from:1 ace_box;
  from_title steps 1;
  if not (steps.ace_at_hand ()) then
    M.fail "ace_not_in_slot" "Box 3 slot 1 does not show species 0x0351";
  log "PC: Box 3 slot 1 shows 0x0351.";
  to_title steps 1

let check_boxes steps ~log t =
  open_at_box1 steps t;
  check_ace steps ~log t;
  ignore
    (List.fold_left
       (fun at (b, slots) ->
         scroll steps t ~from:at b;
         check_empty steps ~log b slots;
         b)
       ace_box empty_slots);
  wrap_to_box1 steps t None;
  steps.close ()

let name_box steps ~log t item b =
  let want = P.box_name item b in
  match title_of steps t b with
  | Some name when name = want ->
      log (Printf.sprintf "PC: Box %d is %s already." b (quoted want))
  | Some name -> steps.name_title ~others:[ name ] want
  | None ->
      log (Printf.sprintf "PC: Box %d's title reads no known name." b);
      steps.name_title ~others:[] want

let enter_code steps ~log t item =
  open_at_box1 steps t;
  List.iter
    (fun b ->
      if b > 1 then next_box steps t b scroll_tries;
      name_box steps ~log t item b)
    box_numbers;
  wrap_to_box1 steps t (Some (P.box_name item 1));
  steps.close ()

let screen_game_steps ~log =
  let box = Ace_trigger.screen_game_steps ~log in
  let rename = Box_rename.screen_game_steps ~log in
  {
    open_move_pokemon = box.open_move_pokemon;
    press = box.press;
    read_title = box.read_title;
    slot_empty = box.slot_empty;
    ace_at_hand = box.ace_at_hand;
    name_title = Box_rename.name_on_title rename ~log;
    close = box.close;
  }

let bad_args e = Error (Pokemon_engine.Failure.cause ~repeats:true "bad_args" e)

let with_item ~options f (_ : Pokemon_engine.Plan.event) (_ : Json_field.obj) =
  match P.run_item options with
  | Error e -> bad_args e
  | Ok (t, item) -> M.run (fun () -> f t item)

let handlers ~log ~options =
  let steps () = screen_game_steps ~log in
  [
    ( "ace_check_boxes",
      with_item ~options (fun t _ -> check_boxes (steps ()) ~log t) );
    ( "ace_enter_code",
      with_item ~options (fun t item -> enter_code (steps ()) ~log t item) );
  ]
