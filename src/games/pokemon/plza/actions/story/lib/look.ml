type effectiveness =
  | No_effect
  | Not_very_effective
  | Effective
  | Super_effective

type map_point = { x : float; y : float }

type t = {
  at_ms : float;
  frame_read : bool;
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
  interact_prompt : bool;
  party_bar : bool;
  map_pin : map_point option;
  minimap_arrow : float option;
  run_prompt : bool;
  main_menu : bool;
  alert_eye : bool;
  minimap : string option;
  battle : bool;
  story_dialog : bool;
  moves : effectiveness option list;
  confirm_row : int option;
}

let empty ~at_ms =
  {
    at_ms;
    frame_read = true;
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
    interact_prompt = false;
    party_bar = false;
    minimap = None;
    map_pin = None;
    minimap_arrow = None;
    run_prompt = false;
    main_menu = false;
    alert_eye = false;
    battle = false;
    story_dialog = false;
    moves = [];
    confirm_row = None;
  }

let no_frame ~at_ms = { (empty ~at_ms) with frame_read = false }
let fade_shows l = l.fade_black || l.fade_white
let text_shows l = l.dialog_box || l.advance_arrow
let text_waiting_for_a l = l.dialog_box && l.advance_arrow
let hud_shows l = l.party_bar || l.controls_hint || l.interact_prompt
let control_shows l = hud_shows l && not l.dialog_box

let scene_busy l =
  l.dialog_box || fade_shows l || l.advance_arrow || l.tutorial_card

let overworld_free l =
  (l.party_bar || l.controls_hint)
  && (not l.dialog_box)
  && (not (fade_shows l))
  && not l.advance_arrow

let platform_hint l = l.controls_hint && (not l.dialog_box) && not l.autosave
let card_shows l = l.tutorial_card

let scene_under_way l =
  if text_shows l || l.choice_box || l.battle || l.tutorial_card then true
  else if hud_shows l then false
  else fade_shows l || not l.screen_still

let moves_shown l = List.exists Option.is_some l.moves

let flags l =
  [
    (l.fade_black, "black fade");
    (l.fade_white, "white fade");
    (l.dialog_box, "text box");
    (l.choice_box, "choice box");
    (l.battle, "battle");
    (l.party_bar, "party bar");
    (l.interact_prompt, "A prompt");
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

let to_walk_screen l : Plza_walk.Screen.t =
  {
    at_ms = l.at_ms;
    home_menu = l.home_menu;
    screen_still = l.screen_still;
    fade_black = l.fade_black;
    fade_white = l.fade_white;
    dialog_box = l.dialog_box;
    advance_arrow = l.advance_arrow;
    player_can_move = l.party_bar;
    controls_hint = l.controls_hint;
    interact_prompt = l.interact_prompt;
    scene_under_way = scene_under_way l;
    battle = l.battle;
    minimap_arrow = l.minimap_arrow;
    map_pin =
      Option.map (fun { x; y } : Plza_walk.Map_leg.point -> { x; y }) l.map_pin;
  }

let wild_battle_on t = t.run_prompt || t.alert_eye
