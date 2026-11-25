module F = Frame_box
open Switch_home.Solid_color

let menu_id = "home.main_menu"
let menu_box : F.t = { x = 1075; y = 238; w = 653; h = 130 }
let channel_max = 255
let orange_red_min = 211
let orange_green_min = 121
let orange_green_max = 204
let orange_blue_max = 59
let orange_min = (orange_red_min, orange_green_min, 0)
let orange_max = (channel_max, orange_green_max, orange_blue_max)
let strip_id = "home.banner_strip"
let strip : F.t = { x = 307; y = 864; w = 1306; h = 22 }
let line1_id = "home.banner_line1"
let line1 : F.t = { x = 288; y = 896; w = 864; h = 49 }
let line2_id = "home.banner_line2"
let line2 : F.t = { x = 288; y = 967; w = 864; h = 54 }

type tile = { row : int; col : int }

let grid = 3
let tile_left = 1046
let tile_top = 344
let tile_across = 267
let tile_down = 222

let tiles =
  List.init (grid * grid) (fun i -> { row = i / grid; col = i mod grid })

let tile_x t = tile_left + (tile_across * t.col)
let tile_y t = tile_top + (tile_down * t.row)
let frame_id t = Printf.sprintf "home.game_frame.%d.%d" t.row t.col
let icon_id t = Printf.sprintf "home.game_icon.%d.%d" t.row t.col

(* The frame's top edge, inside the tile's width; the icon searched 10 px
   round the tile. *)
let frame_inset = 30

let frame_box t : F.t =
  { x = tile_x t + frame_inset; y = tile_y t - 2; w = 134; h = 10 }

let icon_margin = 10
let tile_size = 194

let icon_box t : F.t =
  {
    x = tile_x t - icon_margin;
    y = tile_y t - icon_margin;
    w = tile_size + (2 * icon_margin);
    h = tile_size + (2 * icon_margin);
  }

(* The list's light page above the game's card. *)
let page_id = "home.game_list_page"
let page : F.t = { x = 100; y = 200; w = 800; h = 40 }
let frame_red_min = 200
let frame_green_min = 120
let frame_green_max = 210
let frame_blue_max = 90
let frame_min = (frame_red_min, frame_green_min, 0)
let frame_max = (channel_max, frame_green_max, frame_blue_max)

let probes ~game_icon =
  [
    F.count_probe menu_id menu_box ~min:orange_min ~max:orange_max;
    F.stats_probe strip_id strip;
    F.stats_probe line1_id line1;
    F.stats_probe line2_id line2;
    F.stats_probe page_id page;
  ]
  @ List.concat_map
      (fun t ->
        [
          F.count_probe (frame_id t) (frame_box t) ~min:frame_min ~max:frame_max;
          F.template_probe (icon_id t) (icon_box t) game_icon;
        ])
      tiles

let min_menu_orange = 0.45
let holds m id test = Option.fold ~none:false ~some:test (F.fraction m id)
let main_menu m = holds m menu_id (fun s -> s > min_menu_orange)

type banner = No_banner | Blank | One_line | Two_lines

let min_text_stddev = 60.

let has_text m id =
  Option.fold ~none:false
    ~some:(fun s -> sum s.stddev >= min_text_stddev)
    (stats m id)

let banner m =
  match stats m strip_id with
  | Some s when is_white s -> (
      match (has_text m line1_id, has_text m line2_id) with
      | false, false -> Blank
      | true, false -> One_line
      | _, true -> Two_lines)
  | Some _ | None -> No_banner

let banner_to_string = function
  | No_banner -> "no banner"
  | Blank -> "a blank banner"
  | One_line -> "a one-line banner"
  | Two_lines -> "a two-line banner"

let min_frame = 0.5
let min_page_sum = 400.
let max_page_stddev = 30.

let light_page m =
  Option.fold ~none:false
    ~some:(fun s ->
      sum s.mean >= min_page_sum && sum s.stddev <= max_page_stddev)
    (stats m page_id)

let cursor_tile m =
  if not (light_page m) then None
  else
    List.find_opt
      (fun t -> holds m (frame_id t) (fun s -> s >= min_frame))
      tiles

let max_icon_score = 0.05
let icon_score m t = Option.fold ~none:1. ~some:fst (F.score m (icon_id t))

let game_tile m =
  List.find_opt (fun t -> icon_score m t <= max_icon_score) tiles

let icon_scores m = List.map (icon_score m) tiles
