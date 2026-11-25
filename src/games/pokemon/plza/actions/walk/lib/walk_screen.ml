type t = {
  at_ms : float;
  home_menu : bool;
  screen_still : bool;
  fade_black : bool;
  fade_white : bool;
  dialog_box : bool;
  advance_arrow : bool;
  player_can_move : bool;
  controls_hint : bool;
  interact_prompt : bool;
  scene_under_way : bool;
}

let empty ~at_ms =
  {
    at_ms;
    home_menu = false;
    screen_still = false;
    fade_black = false;
    fade_white = false;
    dialog_box = false;
    advance_arrow = false;
    player_can_move = false;
    controls_hint = false;
    interact_prompt = false;
    scene_under_way = false;
  }

let fade_shows l = l.fade_black || l.fade_white

let player_free l =
  (l.player_can_move || l.controls_hint)
  && not (l.dialog_box || fade_shows l || l.advance_arrow)

let busy_with l =
  if l.advance_arrow then Some "text waiting for A"
  else if l.dialog_box then Some "a text box"
  else if fade_shows l then Some "a fade"
  else None

let shows (event : Plza_rules.Walk_args.end_event) l =
  match event with
  | Fade_white -> l.fade_white
  | Fade_black -> l.fade_black
  | Dialog -> l.dialog_box

let fields l =
  [
    ("home_menu", l.home_menu);
    ("screen_still", l.screen_still);
    ("fade_black", l.fade_black);
    ("fade_white", l.fade_white);
    ("dialog_box", l.dialog_box);
    ("advance_arrow", l.advance_arrow);
    ("player_can_move", l.player_can_move);
    ("controls_hint", l.controls_hint);
    ("interact_prompt", l.interact_prompt);
  ]

let set_name (name, on) = if on then Some name else None

let describe l =
  match List.filter_map set_name (fields l) with
  | [] -> "none"
  | set -> String.concat ", " set
