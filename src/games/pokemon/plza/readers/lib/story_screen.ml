type t = {
  fade : Screen_state.Fade.t;
  dialog_box : bool;
  choice_box : bool;
  advance_arrow : bool;
  controls_hint : bool;
  autosave : bool;
  tutorial_card : bool;
  choice_rows : Choice_rows.t option;
  interact_prompt : bool;
  battle : bool;
  story_dialog : bool;
  moves : Move_symbols.symbol option list;
  party_bar : bool;
  map_pin : Map_pin.point option;
  minimap_arrow : float option;
  run_prompt : bool;
  alert_eye : bool;
  minimap : string option;
}

let fade_id = "story_screen.fade"

let fade_box =
  Native_box.of_fractions { left = 0.1; top = 0.1; width = 0.8; height = 0.8 }

let probes ~picture ~assets =
  List.concat
    [
      Box_color.probe ~picture ~id:fade_id fade_box;
      Dialog_box.probes ~picture ~assets;
      Choice_arrow.probes ~picture ~assets;
      Choice_rows.probes ~picture;
      Advance_arrow.probes ~picture ~assets;
      Controls_hint.probes ~picture;
      Autosave_badge.probes ~picture;
      Tutorial_card.probes ~picture;
      Interact_prompt.probes ~picture ~assets;
      Battle_hud.probes ~picture ~assets;
      Move_symbols.probes ~picture ~assets;
      Party_bar.probes ~picture ~assets;
      Minimap.probes ~picture;
      Run_prompt.probes ~picture ~assets;
      Minimap_arrow.probes ~picture;
      Map_pin.probes ~picture;
      Alert_eye.probes ~picture ~assets;
    ]

let fade m =
  match Box_color.read m fade_id with
  | Some s -> Screen_state.Fade.of_color_stats ~mean:s.mean ~stddev:s.stddev
  | None -> No_fade

let read m =
  let fade = fade m in
  let boxes = fade = No_fade in
  let box = boxes && Dialog_box.shown ~white:Box_only m in
  let rows = Choice_rows.read m in
  let choice =
    boxes && (Choice_arrow.shown m || (box && Option.is_some rows))
  in
  let battle = boxes && Battle_hud.shown m in
  {
    fade;
    dialog_box = box || choice;
    choice_box = choice;
    advance_arrow = Advance_arrow.shown m;
    controls_hint = (not battle) && Controls_hint.shown m;
    autosave = Autosave_badge.shown m;
    tutorial_card = Tutorial_card.shown m;
    choice_rows = (if choice then rows else None);
    interact_prompt = boxes && (not box) && Interact_prompt.shown m;
    battle;
    story_dialog = Dialog_box.shown ~white:Box_and_arrow m;
    moves = Move_symbols.read m;
    party_bar = boxes && (not box) && Party_bar.shown m;
    map_pin = Map_pin.read m;
    minimap_arrow = Minimap_arrow.read m;
    run_prompt = Run_prompt.shown m;
    alert_eye = Alert_eye.shown m;
    minimap = (if boxes && not box then Minimap.read m else None);
  }

let to_string t =
  let flag name on = if on then [ name ] else [] in
  let rows =
    match t.choice_rows with
    | Some r -> [ Printf.sprintf "row %d of %d" r.selected r.count ]
    | None -> []
  in
  let shown =
    List.concat
      [
        (match t.fade with No_fade -> [] | f -> [ Screen_state.Fade.name f ]);
        flag "dialog box" t.dialog_box;
        flag "choice box" t.choice_box;
        rows;
        flag "advance arrow" t.advance_arrow;
        flag "controls hint" t.controls_hint;
        flag "autosave" t.autosave;
        flag "tutorial card" t.tutorial_card;
        flag "A prompt" t.interact_prompt;
        flag "battle" t.battle;
        flag "story dialog" t.story_dialog;
        (if List.exists Option.is_some t.moves then [ "move symbols" ] else []);
        flag "party bar" t.party_bar;
        (match t.minimap with Some n -> [ "minimap " ^ n ] | None -> []);
        flag "Run prompt" t.run_prompt;
        flag "alert eye" t.alert_eye;
      ]
  in
  if shown = [] then "nothing" else String.concat ", " shown
