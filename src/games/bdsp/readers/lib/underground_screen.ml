module PB = Switch_home.Picture_box
module SC = Switch_home.Solid_color

type t = {
  fade : Screen_state.Fade.t;
  mining_wall : bool;
  dialog : bool;
  choice_box : bool;
  menu : bool;
  battle : bool;
  sparkles : Minimap_sparkles.nearby;
}

let fade_probe_id = "bdsp_screen_fade"
let choice_probe_id = "bdsp_screen_choice_box"

(* White right-aligned Yes/No choice box measured from run-46/frames/000027.jpg:
   white interior spans x=0.72..0.82, y=0.65..0.77; right half is pure white
   background with dark text only on the left. *)
let choice_box_rect : Wire.box = { x = 0.77; y = 0.66; w = 0.05; h = 0.10 }
let choice_min_rgb = 215.
let choice_max_std_sum = 50.

let single_probe ~picture ~id box =
  match PB.clipped ~picture box with
  | Some b -> [ Wire.color_stats_probe ~id ~box:b ~delivery:Every ]
  | None -> []

let probes ~picture =
  single_probe ~picture ~id:fade_probe_id Screen_state.Fade.middle_box
  @ single_probe ~picture ~id:choice_probe_id choice_box_rect
  @ Dialog_detector.probes ~picture
  @ Menu_detector.probes ~picture ()
  @ Battle_detector.probes ~picture
  @ Mining_grid.tool_panel_probes ~picture
  @ Minimap_sparkles.probes ~picture

let read_fade m =
  match SC.stats m fade_probe_id with
  | Some s -> Screen_state.Fade.of_color_stats ~mean:s.mean ~stddev:s.stddev
  | None -> Screen_state.Fade.No_fade

let read_choice_box m =
  match SC.stats m choice_probe_id with
  | Some s ->
      s.mean.r >= choice_min_rgb && s.mean.g >= choice_min_rgb
      && s.mean.b >= choice_min_rgb
      && SC.sum s.stddev <= choice_max_std_sum
  | None -> false

let faded_state fade =
  {
    fade;
    mining_wall = false;
    dialog = false;
    choice_box = false;
    menu = false;
    battle = false;
    sparkles = Minimap_sparkles.none;
  }

let read_no_fade m =
  let mining_wall = Mining_grid.on_mining_screen m in
  let dialog = Dialog_detector.shown m in
  let choice_box = dialog && read_choice_box m in
  let menu = (not mining_wall) && Menu_detector.shown m in
  let battle = (not mining_wall) && (not dialog) && Battle_detector.shown m in
  let free = not (mining_wall || dialog || menu || battle) in
  let sparkles =
    if free then Minimap_sparkles.read m else Minimap_sparkles.none
  in
  { fade = No_fade; mining_wall; dialog; choice_box; menu; battle; sparkles }

let read m =
  match read_fade m with
  | (Screen_state.Fade.Black | White) as fade -> faded_state fade
  | No_fade -> read_no_fade m

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
  @ (if s.choice_box then [ "choice_box" ] else [])
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
