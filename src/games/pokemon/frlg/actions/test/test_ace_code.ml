(* Ace_code on a fake box screen: 14 boxes of 30 slots with their titles
   and wallpapers (a new game's unless [walls] says otherwise; [None] reads as
   none of the four), the hand on the title or a slot, RIGHT on the title to
   the next box, and a rename that sets the shown box's title. Run against the
   real preset table. *)

open Frlg_actions
module C = Ace_code
module W = Frlg_readers.Pc_box_screen

let table = Result.get_ok (Ace_presets.load ())
let master = Option.get (Ace_presets.find table "master-ball")
let luxury = Option.get (Ace_presets.find table "luxury-ball")
let ace = "0x0351"

type fake = {
  slots : string option array array;
  titles : string array;
  walls : W.wallpaper option array;
  mutable box : int;
  mutable on_title : bool;
  mutable slot : int;  (** 0-based *)
  mutable typed : string list;
  unread : int option;  (** a box (0-based) whose title reads as nothing *)
  mutable drops : int;  (** RIGHT presses on the title still to drop *)
  drop_after_rename : int;  (** RIGHT presses dropped after each rename *)
}

let press f (b : Wire.button) =
  match b with
  | Up when not f.on_title ->
      if f.slot < 6 then f.on_title <- true else f.slot <- f.slot - 6
  | Down when f.on_title ->
      f.on_title <- false;
      f.slot <- 2
  | Right when f.on_title && f.drops > 0 -> f.drops <- f.drops - 1
  | Right when f.on_title -> f.box <- (f.box + 1) mod 14
  | Left when f.on_title -> f.box <- (f.box + 13) mod 14
  | Down -> f.slot <- f.slot + 6
  | Right -> f.slot <- f.slot + 1
  | Left -> f.slot <- f.slot - 1
  | _ -> ()

let steps f : C.game_steps =
  {
    open_move_pokemon =
      (fun () ->
        f.on_title <- false;
        f.slot <- 0);
    press = press f;
    read_title =
      (fun cs ->
        let t = f.titles.(f.box) in
        if Some f.box <> f.unread && List.mem t cs then Some t else None);
    read_wallpaper = (fun () -> f.walls.(f.box));
    slot_empty = (fun () -> Some (f.slots.(f.box).(f.slot) = None));
    ace_at_hand = (fun () -> f.slots.(f.box).(f.slot) = Some ace);
    name_title =
      (fun ~others:_ name ->
        f.typed <- Printf.sprintf "%d:%s" (f.box + 1) name :: f.typed;
        f.titles.(f.box) <- name;
        f.drops <- f.drop_after_rename);
    close = (fun () -> ());
  }

let new_game i = Some (W.default_wallpaper (i + 1))

let make ?(box = 2) ?(titles = fun i -> Printf.sprintf "BOX%d" (i + 1))
    ?(walls = new_game) ?(stray = None) ?unread ?(drop_after_rename = 0) () =
  let slots = Array.init 14 (fun _ -> Array.make 30 None) in
  slots.(2).(0) <- Some ace;
  slots.(0).(0) <- Some "MIMIEN";
  Option.iter (fun (b, s) -> slots.(b - 1).(s - 1) <- Some "stray") stray;
  {
    slots;
    titles = Array.init 14 titles;
    walls = Array.init 14 walls;
    box;
    on_title = false;
    slot = 0;
    typed = [];
    unread;
    drops = 0;
    drop_after_rename;
  }

let outcome f run =
  match run (steps f) with
  | () -> "ok"
  | exception Menu_input.Action_failed c -> c.code ^ ": " ^ c.detail

let check f = outcome f (fun s -> C.check_boxes s ~log:ignore table)

let enter item f =
  let o = outcome f (fun s -> C.enter_code s ~log:ignore table item) in
  Printf.sprintf "%s; typed %d: %s" o (List.length f.typed)
    (String.concat ", " (List.rev f.typed))

let named item i = Ace_presets.box_name item (i + 1)
let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "ace_code"
    [
      case "the boxes as ace_setup leaves them" (fun () -> check (make ())) "ok";
      case "a Pokémon in Box 13 slot 9"
        (fun () -> check (make ~stray:(Some (13, 9)) ()))
        "ace_box_not_empty: Box 13 slot 9 holds a Pokémon";
      case "Box 13 slot 6 may hold one"
        (fun () -> check (make ~stray:(Some (13, 6)) ()))
        "ok";
      case "a Pokémon in Box 14 slot 30"
        (fun () -> check (make ~stray:(Some (14, 30)) ()))
        "ace_box_not_empty: Box 14 slot 30 holds a Pokémon";
      case "no 0x0351 in Box 3 slot 1"
        (fun () ->
          let f = make () in
          f.slots.(2).(0) <- None;
          check f)
        "ace_not_in_slot: Box 3 slot 1 does not show species 0x0351";
      case "default names: all 14 typed, from Box 1"
        (fun () -> enter master (make ~box:7 ()))
        "ok; typed 14: 1:xFUnDRRn, 2:……o/E!n, 3:EE …l‘, 4:E♀BRm, 5:G……o, \
         6:EEEJD!n, 7:EEIB!n, 8:EI/!n, 9:'BRm, 10: FoHIoor, 11:xn, 12:A, 13:A, \
         14:A";
      case "Master Ball's code, then Luxury Ball's: only Box 5 retyped"
        (fun () -> enter luxury (make ~titles:(named master) ()))
        "ok; typed 1: 5:Q……o";
      case "the same item again: nothing typed"
        (fun () -> enter master (make ~titles:(named master) ()))
        "ok; typed 0: ";
      case "a title that reads no name is retyped"
        (fun () -> enter master (make ~titles:(named master) ~unread:5 ()))
        "ok; typed 1: 6:EEEJD!n";
      case "a box named as another box: stopped, not renamed"
        (fun () ->
          let titles i = if i = 5 then "BOX7" else named master i in
          enter master (make ~titles ()))
        "ace_box_lost: Box 6's title reads \"BOX7\", another box's name; typed \
         0: ";
      case "a RIGHT dropped after each rename: pressed again"
        (fun () ->
          let f = make ~titles:(named luxury) ~drop_after_rename:1 () in
          f.titles.(3) <- "BOX4";
          let o = enter master f in
          o ^ "; Box 6 " ^ f.titles.(5))
        "ok; typed 2: 4:E♀BRm, 5:G……o; Box 6 EEEJD!n";
      case "four RIGHTs dropped: stopped"
        (fun () ->
          enter master (make ~titles:(named luxury) ~drop_after_rename:4 ()))
        "ace_box_lost: RIGHT did not reach Box 6; typed 1: 5:G……o";
      case "Box 13 left BOX13, the rest right: renamed, the wrap reaches Box 1"
        (fun () ->
          let titles i = if i = 12 then "BOX13" else named master i in
          enter master (make ~titles ()))
        "ok; typed 1: 13:A";
      case "Box 6's wallpaper changed by hand: stopped before Box 13 is read"
        (fun () ->
          check
            (make
               ~walls:(fun i -> if i = 5 then Some W.Desert else new_game i)
               ()))
        "ace_box_wallpaper: Box 6 shows the Desert wallpaper, not its default \
         City: set it back to City (WALLPAPER on the box title's menu) before \
         the code is entered";
      case "Box 1's wallpaper none of the four: stopped at once"
        (fun () ->
          enter master
            (make ~walls:(fun i -> if i = 0 then None else new_game i) ()))
        "ace_box_wallpaper: Box 1 shows none of the new game's wallpapers \
         (Forest, City, Desert, Savanna), not its default Forest: set it back \
         to Forest (WALLPAPER on the box title's menu) before the code is \
         entered; typed 0: ";
      case
        "a RIGHT dropped between Boxes 12 and 13, both A: told by the \
         wallpaper, pressed again"
        (fun () ->
          let titles i = if i = 11 then "BOX12" else named master i in
          let f = make ~titles ~drop_after_rename:1 () in
          let o = enter master f in
          o ^ "; Box 13 " ^ f.titles.(12))
        "ok; typed 1: 12:A; Box 13 A";
      case "no Box 1 anywhere"
        (fun () -> enter master (make ~titles:(fun _ -> "?") ()))
        "ace_box_lost: no box title reads as Box 1; typed 0: ";
    ]
