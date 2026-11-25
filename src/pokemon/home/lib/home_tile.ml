module F = Frame_box

(* Switch_home.Home_screen's tile slots: left 0.098 + 0.2125 k, 0.17 wide;
   art 0.30 to 0.60 high. *)
let frame_width = 1920.
let tile_left = 0.098
let tile_pitch = 0.2125
let tiles = 4

let art k : F.t =
  {
    x =
      Float.to_int (frame_width *. (tile_left +. (tile_pitch *. float_of_int k)));
    y = 324;
    w = 326;
    h = 324;
  }

let tile_id k = Printf.sprintf "home.app_tile%d" k

(* The cursor tile's title, over the row: left-aligned from x 125 while the
   row has not scrolled, over the selected tile once it has (console B,
   2026-11-25: "Pokémon: Let's Go, Pikachu!" at x 1230 to 1815). "Pokémon
   HOME"'s "HOME" is 142x48, its top at y 218; it is searched along the whole
   title row, 12 pixels above and below. "Pokémon" alone would match every
   title. *)
let title_window : F.t = { x = 0; y = 206; w = 1920; h = 72 }
let title_id = "home.app_title"

(* The title's cyan, as ink: red under 120, green over 150, blue over 200. *)
let cyan_red_max = 120
let cyan_green_min = 150
let cyan_blue_min = 200
let channel_max = 255

let cyan : Wire.color_range =
  {
    min = (0, cyan_green_min, cyan_blue_min);
    max = (cyan_red_max, channel_max, channel_max);
  }

let probes ~art:art_png ~title =
  F.template_probe ~ink:cyan title_id title_window title
  :: List.init tiles (fun k -> F.template_probe (tile_id k) (art k) art_png)

let max_title_score = 0.08
let title_score m = Option.map fst (F.score m title_id)

let on_home_tile m =
  Option.fold ~none:false ~some:(fun s -> s <= max_title_score) (title_score m)

let max_score = 0.05

let tile m =
  List.find_opt
    (fun k ->
      Option.fold ~none:false
        ~some:(fun (s, _) -> s <= max_score)
        (F.score m (tile_id k)))
    (List.init tiles Fun.id)

let teal_green_min = 120
let teal_blue_min = 110
let teal_red_max = 70
let teal_green_max = 235
let teal_blue_max = 185

let tile_color : Switch_home.Home_screen.tile_color =
  {
    min = (0, teal_green_min, teal_blue_min);
    max = (teal_red_max, teal_green_max, teal_blue_max);
  }
