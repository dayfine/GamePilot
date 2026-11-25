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
  {
    fade;
    dialog_box = box || choice;
    choice_box = choice;
    advance_arrow = Advance_arrow.shown m;
    controls_hint = Controls_hint.shown m;
    autosave = Autosave_badge.shown m;
    tutorial_card = Tutorial_card.shown m;
    choice_rows = (if choice then rows else None);
    interact_prompt = boxes && (not box) && Interact_prompt.shown m;
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
      ]
  in
  if shown = [] then "nothing" else String.concat ", " shown
