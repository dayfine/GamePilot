(* Pc_box: the walk from the PC to the MOVE POKéMON box screen and back, on a
   fake PC made up here. Its screens answer the presses the way the game's do
   (A at the PC shows the boot message, B on it the PC list, A on BILL'S PC the
   storage menu, A on MOVE POKéMON the box screen, B backs out a screen at a
   time). [stuck] keeps it on a fade whatever is pressed. *)

open Frlg_actions
module S = Frlg_readers.Pc_screen
module P = Pc_deposit_steps

let case name input expectation = { Table_test.name; input; expectation }

let storage_rows =
  [ "WITHDRAW POKéMON"; "DEPOSIT POKéMON"; "MOVE POKéMON"; "MOVE ITEMS" ]

type pc = {
  mutable screen : S.screen;
  mutable cursor : int;
  mutable presses : string list;
  stuck : bool;
}

let pc ?(stuck = false) ?(cursor = 0) screen =
  { screen; cursor; presses = []; stuck }

let label g =
  match g.screen with
  | Pc_list -> Some (if g.cursor = 0 then "BILL'S PC" else "PROF. OAK'S PC")
  | Storage_menu -> List.nth_opt storage_rows g.cursor
  | _ -> None

let look g () : P.look =
  let screen = if g.stuck then S.Other else g.screen in
  {
    view = { screen; cursor = Some g.cursor };
    label = label g;
    species = None;
    box_full = false;
  }

let go g screen cursor =
  g.screen <- screen;
  g.cursor <- cursor

let press g (p : P.press) =
  g.presses <- P.press_to_string p :: g.presses;
  if not g.stuck then
    match (g.screen, p) with
    | Overworld, A -> go g Text 0
    | Text, B -> go g Pc_list 0
    | Pc_list, A when g.cursor = 0 -> go g Storage_menu 0
    | Pc_list, Up -> g.cursor <- max 0 (g.cursor - 1)
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
      Pokemon_checkpoints.Failure.cause_to_string c

let failure why =
  Pokemon_checkpoints.Failure.(cause_to_string (cause "pc_box" why))

let walk_cases =
  [
    case "open: from the overworld facing the PC"
      (walk Pc_box.to_box_screen (pc Overworld))
      (S.screen_name Box_grid ^ " after [A B A DOWN DOWN A]");
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

let look_at ?cursor ?label screen : P.look =
  { view = { screen; cursor }; label; species = None; box_full = false }

let next o l () =
  match Pc_box.open_next o l with
  | At_box_screen -> "at the box screen"
  | Press (p, o) ->
      Printf.sprintf "%s (booted %b, chosen %b)" (P.press_to_string p) o.booted
        o.chosen

let chosen = { Pc_box.booted = true; chosen = true }

let next_cases =
  [
    case "next: the overworld before A at the PC: A"
      (next Pc_box.opening (look_at Overworld))
      "A (booted true, chosen false)";
    case "next: the overworld once MOVE POKéMON was chosen: the box screen"
      (next chosen (look_at Overworld))
      "at the box screen";
    case "next: MOVE POKéMON's row with its label unread: no A"
      (next Pc_box.opening (look_at ~cursor:2 Storage_menu))
      "UP (booted true, chosen false)";
    case "next: the PC list's top row unread: no A"
      (next Pc_box.opening (look_at ~cursor:0 Pc_list))
      "UP (booted true, chosen false)";
  ]

let () = Table_test.run "pc box" (walk_cases @ next_cases)
