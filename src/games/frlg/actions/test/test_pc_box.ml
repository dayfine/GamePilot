(* Pc_box: the walks from the PC to the MOVE POKéMON box screen and back, and
   to WITHDRAW ITEM's list, on a fake PC made up here. Its screens answer the
   presses the way the game's do (A at the PC shows the boot message, B on it
   the PC list, A on BILL'S PC the storage menu, A on MOVE POKéMON the box
   screen; A on the player's PC its menu, A on ITEM STORAGE that menu, A on
   WITHDRAW ITEM the item list; B backs out a screen at a time). The player's
   PC's menus read as a message with their top row's label ([menu]).
   [stuck] keeps it on a fade whatever is pressed. [late_list] puts "Which PC
   should be accessed?" between the boot message and the PC list: a message
   still printing, the list behind it at the next press, which a B lands on
   and cancels, turning the PC off (console B, 2026-11-25). *)

open Frlg_actions
module S = Frlg_readers.Pc_screen
module P = Pc_deposit_steps

let case name input expectation = { Table_test.name; input; expectation }

let storage_rows =
  [ "WITHDRAW POKéMON"; "DEPOSIT POKéMON"; "MOVE POKéMON"; "MOVE ITEMS" ]

type pc = {
  mutable screen : S.screen;
  mutable cursor : int;
  mutable menu : string option;  (** The player's PC menu shown. *)
  mutable item_list : bool;
  mutable presses : string list;
  mutable which_pc : bool;  (** "Which PC should be accessed?" printing. *)
  stuck : bool;
  late_list : bool;
}

let pc ?(stuck = false) ?(late_list = false) ?(cursor = 0) ?menu screen =
  {
    screen;
    cursor;
    menu;
    item_list = false;
    presses = [];
    which_pc = false;
    stuck;
    late_list;
  }

let label g =
  match g.screen with
  | Pc_list -> Some (if g.cursor = 0 then "BILL'S PC" else "PROF. OAK'S PC")
  | Storage_menu -> List.nth_opt storage_rows g.cursor
  | _ -> None

let look g (target : Pc_box.target) : Pc_box.look =
  let screen = if g.stuck then S.Other else g.screen in
  let withdraw = target = Withdraw_item && not g.stuck in
  {
    pc =
      {
        view = { screen; cursor = Some g.cursor };
        label = label g;
        species = None;
        box_full = false;
        remove_mail = false;
      };
    menu_top = (if withdraw then g.menu else None);
    item_list = withdraw && g.item_list;
  }

let go g screen cursor =
  g.screen <- screen;
  g.cursor <- cursor;
  g.menu <- None

let menu g name =
  go g Text 0;
  g.menu <- Some name

let list_opens g (p : P.press) =
  g.which_pc <- false;
  if p = B then go g Overworld 0 else go g Pc_list 0

let press g (p : P.press) =
  g.presses <- P.press_to_string p :: g.presses;
  if g.which_pc then list_opens g p
  else if not g.stuck then
    match (g.screen, p) with
    | Overworld, A -> go g Text 0
    | Text, A when g.menu = Some "ITEM STORAGE" -> menu g "WITHDRAW ITEM"
    | Text, A when g.menu = Some "WITHDRAW ITEM" ->
        go g Overworld 0;
        g.item_list <- true
    | Text, B when g.menu = Some "WITHDRAW ITEM" -> menu g "ITEM STORAGE"
    | Text, B when g.menu <> None -> go g Pc_list 1
    | Text, B when g.late_list -> g.which_pc <- true
    | Text, B -> go g Pc_list 0
    | Pc_list, A when g.cursor = 0 -> go g Storage_menu 0
    | Pc_list, A when g.cursor = 1 -> menu g "ITEM STORAGE"
    | Pc_list, Up -> g.cursor <- max 0 (g.cursor - 1)
    | Pc_list, Down -> g.cursor <- g.cursor + 1
    | Storage_menu, A when g.cursor = 2 -> go g Box_grid 0
    | Storage_menu, Down -> g.cursor <- g.cursor + 1
    | Storage_menu, Up -> g.cursor <- g.cursor - 1
    | Storage_menu, B -> go g Overworld 0
    | Box_grid, B -> go g Storage_menu 2
    | _ -> ()

let fake_game_steps g : Pc_box.game_steps = { look = look g; press = press g }

let walk f g () =
  match f ~log:ignore (fake_game_steps g) with
  | () ->
      Printf.sprintf "%s after [%s]" (S.screen_name g.screen)
        (String.concat " " (List.rev g.presses))
  | exception Menu_input.Action_failed c ->
      Pokemon_engine.Failure.cause_to_string c

let failure why = Pokemon_engine.Failure.(cause_to_string (cause "pc_box" why))

let walk_cases =
  [
    case "open: from the overworld facing the PC"
      (walk Pc_box.to_box_screen (pc Overworld))
      (S.screen_name Box_grid ^ " after [A wait B A DOWN DOWN A]");
    case "open: a message with the PC list behind it gets a wait, not B"
      (walk Pc_box.to_box_screen (pc ~late_list:true Overworld))
      (S.screen_name Box_grid ^ " after [A wait B wait A DOWN DOWN A]");
    case "open: the storage menu's cursor below MOVE POKéMON goes up"
      (walk Pc_box.to_box_screen (pc ~cursor:3 Storage_menu))
      (S.screen_name Box_grid ^ " after [UP A]");
    case "open: the PC list's cursor on another PC goes up"
      (walk Pc_box.to_box_screen (pc ~cursor:1 Pc_list))
      (S.screen_name Box_grid ^ " after [UP A DOWN DOWN A]");
    case "open: a screen that never settles fails after the looks"
      (walk Pc_box.to_box_screen (pc ~stuck:true Overworld))
      (failure "the box screen did not open");
    case "leave: B from the box screen, B from the storage menu"
      (walk Pc_box.leave (pc Box_grid))
      (S.screen_name Overworld ^ " after [B B]");
    case "leave: a screen that never settles fails after the looks"
      (walk Pc_box.leave (pc ~stuck:true Box_grid))
      (failure "the overworld did not come back");
  ]

let withdraw ~log steps = Pc_box.open_menu ~log steps Withdraw_item

let item_list g () =
  match withdraw ~log:ignore (fake_game_steps g) with
  | () ->
      Printf.sprintf "item list %b after [%s]" g.item_list
        (String.concat " " (List.rev g.presses))
  | exception Menu_input.Action_failed c ->
      Pokemon_engine.Failure.cause_to_string c

let withdraw_cases =
  [
    case "withdraw: from the overworld facing the PC"
      (item_list (pc Overworld))
      "item list true after [A wait B DOWN A A A]";
    case "withdraw: the PC list's cursor below the player's PC goes up"
      (item_list (pc ~cursor:3 Pc_list))
      "item list true after [UP UP A A A]";
    case "withdraw: on ITEM STORAGE's menu already"
      (item_list (pc ~menu:"WITHDRAW ITEM" Text))
      "item list true after [A]";
    case "withdraw: a menu whose label does not read is backed out of"
      (item_list (pc ~menu:"MAILBOX" Text))
      "item list true after [wait B A A A]";
    case "withdraw: a message with the PC list behind it gets a wait, not B"
      (item_list (pc ~late_list:true Overworld))
      "item list true after [A wait B wait DOWN A A A]";
    case "withdraw: a screen that never settles fails after the looks"
      (item_list (pc ~stuck:true Overworld))
      (failure "WITHDRAW ITEM's list did not open");
  ]

let look_at ?cursor ?label ?menu_top ?(item_list = false) screen : Pc_box.look =
  {
    pc =
      {
        view = { screen; cursor };
        label;
        species = None;
        box_full = false;
        remove_mail = false;
      };
    menu_top;
    item_list;
  }

let next ?(target = Pc_box.Move_pokemon) o l () =
  match Pc_box.open_next target o l with
  | Opened -> "at the box screen"
  | Press (p, o) ->
      Printf.sprintf "%s (booted %b, chosen %b, message seen %b)"
        (P.press_to_string p) o.booted o.chosen o.message_seen

let booted = { Pc_box.opening with booted = true }
let chosen = { booted with chosen = true }

let next_cases =
  [
    case "next: the overworld before A at the PC: A"
      (next Pc_box.opening (look_at Overworld))
      "A (booted true, chosen false, message seen false)";
    case "next: the overworld once MOVE POKéMON was chosen: the box screen"
      (next chosen (look_at Overworld))
      "at the box screen";
    case "next: a message at the first look: a wait"
      (next booted (look_at Text))
      "wait (booted true, chosen false, message seen true)";
    case "next: a message at the second look in a row: B"
      (next { booted with message_seen = true } (look_at Text))
      "B (booted true, chosen false, message seen false)";
    case "next: the PC list after a message: the second look starts over"
      (next { booted with message_seen = true } (look_at ~cursor:1 Pc_list))
      "UP (booted true, chosen false, message seen false)";
    case "next: MOVE POKéMON's row with its label unread: no A"
      (next Pc_box.opening (look_at ~cursor:2 Storage_menu))
      "UP (booted true, chosen false, message seen false)";
    case "next: the PC list's top row unread: no A"
      (next Pc_box.opening (look_at ~cursor:0 Pc_list))
      "UP (booted true, chosen false, message seen false)";
    case "next, withdraw: WITHDRAW ITEM's label: A, chosen"
      (next ~target:Withdraw_item Pc_box.opening
         (look_at ~menu_top:"WITHDRAW ITEM" Text))
      "A (booted true, chosen true, message seen false)";
    case "next, withdraw: a message once WITHDRAW ITEM was chosen: wait"
      (next ~target:Withdraw_item chosen (look_at Text))
      "wait (booted true, chosen true, message seen false)";
    case "next, withdraw: the list, read as the overworld: done"
      (next ~target:Withdraw_item chosen (look_at ~item_list:true Overworld))
      "at the box screen";
  ]

let () = Table_test.run "pc box" (walk_cases @ withdraw_cases @ next_cases)
