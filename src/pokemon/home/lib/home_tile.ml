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

(* "Pokémon HOME"'s "HOME" (142x48, its top at y 218), searched along HOME's
   title row by Switch_home.Home_title. "Pokémon" alone would match every
   title. *)
let title_id = "home.app_title"

let probes ~art:art_png ~title =
  Switch_home.Home_title.probe title_id title
  :: List.init tiles (fun k -> F.template_probe (tile_id k) (art k) art_png)

let on_home_tile m = Switch_home.Home_title.shows m title_id
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
