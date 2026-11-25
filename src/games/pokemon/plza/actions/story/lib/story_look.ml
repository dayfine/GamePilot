type t = {
  at_ms : float;
  home_menu : bool;
  screen_still : bool;
  fade_black : bool;
  fade_white : bool;
  dialog_box : bool;
  choice_box : bool;
  choice_rows : (int * int) option;
  advance_arrow : bool;
  controls_hint : bool;
  autosave : bool;
  tutorial_card : bool;
  confirm_row : int option;
}

let empty ~at_ms =
  {
    at_ms;
    home_menu = false;
    screen_still = false;
    fade_black = false;
    fade_white = false;
    dialog_box = false;
    choice_box = false;
    choice_rows = None;
    advance_arrow = false;
    controls_hint = false;
    autosave = false;
    tutorial_card = false;
    confirm_row = None;
  }

let fade_shows l = l.fade_black || l.fade_white
let text_shows l = l.dialog_box || l.advance_arrow
let text_waiting_for_a l = l.dialog_box && l.advance_arrow
let control_shows l = l.controls_hint && not l.dialog_box

let overworld_free l =
  l.controls_hint && (not l.dialog_box)
  && (not (fade_shows l))
  && not l.advance_arrow

let platform_hint l = l.controls_hint && (not l.dialog_box) && not l.autosave
let card_shows l = l.tutorial_card

let flags l =
  [
    (l.fade_black, "black fade");
    (l.fade_white, "white fade");
    (l.dialog_box, "text box");
    (l.choice_box, "choice box");
    (l.screen_still, "still");
    (l.controls_hint, "controls hint");
    (l.advance_arrow, "advance arrow");
    (l.tutorial_card, "tutorial card");
    (l.autosave, "autosave");
  ]

let describe l =
  let shown =
    List.filter_map (fun (on, name) -> if on then Some name else None) (flags l)
  in
  if shown = [] then "nothing" else String.concat ", " shown

let to_walk_screen l : Plza_walk.Walk_screen.t =
  {
    at_ms = l.at_ms;
    home_menu = l.home_menu;
    screen_still = l.screen_still;
    fade_black = l.fade_black;
    fade_white = l.fade_white;
    dialog_box = l.dialog_box;
    advance_arrow = l.advance_arrow;
    player_can_move = false;
    controls_hint = l.controls_hint;
  }
