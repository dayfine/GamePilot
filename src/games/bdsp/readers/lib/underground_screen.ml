module PB = Switch_home.Picture_box
module SC = Switch_home.Solid_color

type t = {
  fade : Screen_state.Fade.t;
  mining_wall : bool;
  dialog : bool;
  menu : bool;
  battle : bool;
  sparkles : Minimap_sparkles.nearby;
}

let fade_probe_id = "bdsp_screen_fade"

let fade_probes ~picture =
  match PB.clipped ~picture Screen_state.Fade.middle_box with
  | Some box ->
      [ Wire.color_stats_probe ~id:fade_probe_id ~box ~delivery:Every ]
  | None -> []

let probes ~picture =
  fade_probes ~picture
  @ Dialog_detector.probes ~picture
  @ Menu_detector.probes ~picture ()
  @ Battle_detector.probes ~picture
  @ Mining_grid.tool_panel_probes ~picture
  @ Minimap_sparkles.probes ~picture

let read_fade m =
  match SC.stats m fade_probe_id with
  | Some s -> Screen_state.Fade.of_color_stats ~mean:s.mean ~stddev:s.stddev
  | None -> Screen_state.Fade.No_fade

let read m =
  let fade = read_fade m in
  match fade with
  | Screen_state.Fade.Black | White ->
      {
        fade;
        mining_wall = false;
        dialog = false;
        menu = false;
        battle = false;
        sparkles = Minimap_sparkles.none;
      }
  | No_fade ->
      let mining_wall = Mining_grid.on_mining_screen m in
      let dialog = Dialog_detector.shown m in
      let menu = (not mining_wall) && Menu_detector.shown m in
      let battle =
        (not mining_wall) && (not dialog) && Battle_detector.shown m
      in
      let free = not (mining_wall || dialog || menu || battle) in
      let sparkles =
        if free then Minimap_sparkles.read m else Minimap_sparkles.none
      in
      { fade; mining_wall; dialog; menu; battle; sparkles }

let to_facts s =
  let free_control =
    s.fade = Screen_state.Fade.No_fade
    && not (s.mining_wall || s.dialog || s.menu || s.battle)
  in
  {
    Screen_state.Facts.none with
    fade = s.fade;
    dialog = s.dialog;
    battle = s.battle;
    free_control;
  }

let active_tags s =
  (if s.mining_wall then [ "mining_wall" ] else [])
  @ (if s.dialog then [ "dialog" ] else [])
  @ (if s.menu then [ "menu" ] else [])
  @ if s.battle then [ "battle" ] else []

let no_fade_string s =
  match active_tags s with
  | [] ->
      Printf.sprintf "overworld (sparkles: %s)"
        (Minimap_sparkles.to_string s.sparkles)
  | xs -> String.concat ", " xs

let to_string s =
  match s.fade with
  | Screen_state.Fade.Black | White -> Screen_state.Fade.name s.fade
  | No_fade -> no_fade_string s
