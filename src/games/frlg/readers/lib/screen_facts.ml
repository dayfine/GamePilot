let fade_id = "fade"

let probes =
  Solid_color.probe ~id:fade_id Screen_state.Fade.middle_box
  :: (Dark_corners.probes @ Dialog.probes @ Battle_screen.probes)

let fade m =
  match Solid_color.read m fade_id with
  | Some { mean; stddev } -> Screen_state.Fade.of_color_stats ~mean ~stddev
  | None -> Screen_state.Fade.No_fade

let of_measurements m : Screen_state.Facts.t =
  if Dark_corners.dark_corners m then Screen_state.Facts.none
  else
    match fade m with
    | (Black | White) as fade -> { Screen_state.Facts.none with fade }
    | No_fade ->
        let battle = Battle_screen.battle_shows m in
        let dialog =
          (not battle) && (Dialog.dialog_up m || Dialog.selection_dialog m)
        in
        { Screen_state.Facts.none with battle; dialog }
