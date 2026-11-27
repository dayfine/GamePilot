module F = Frame_box
open Switch.Solid_color

type rgb = { r : int; g : int; b : int }
type color_bounds = { lo : rgb; hi : rgb }

let rgb_tuple { r; g; b } = (r, g, b)
let menu_id = "home.main_menu"
let menu_box : F.t = { x = 1075; y = 238; w = 653; h = 130 }

let orange =
  { lo = { r = 211; g = 121; b = 0 }; hi = { r = 255; g = 204; b = 59 } }

let strip_id = "home.banner_strip"
let strip : F.t = { x = 307; y = 864; w = 1306; h = 22 }
let line1_id = "home.banner_line1"
let line1 : F.t = { x = 288; y = 896; w = 864; h = 49 }
let line2_id = "home.banner_line2"
let line2 : F.t = { x = 288; y = 967; w = 864; h = 54 }

type tile = { row : int; col : int }

type tile_geom = {
  grid : int;
  left : int;
  top : int;
  across : int;
  down : int;
  frame_inset : int;
  icon_margin : int;
  tile_size : int;
}

let tg =
  {
    grid = 3;
    left = 1046;
    top = 344;
    across = 267;
    down = 222;
    frame_inset = 30;
    icon_margin = 10;
    tile_size = 194;
  }

let tiles =
  List.init (tg.grid * tg.grid) (fun i ->
      { row = i / tg.grid; col = i mod tg.grid })

let tile_x t = tg.left + (tg.across * t.col)
let tile_y t = tg.top + (tg.down * t.row)
let frame_id t = Printf.sprintf "home.game_frame.%d.%d" t.row t.col
let icon_id t = Printf.sprintf "home.game_icon.%d.%d" t.row t.col

(* The frame's top edge, inside the tile's width; the icon searched 10 px
   round the tile. *)
let frame_box t : F.t =
  { x = tile_x t + tg.frame_inset; y = tile_y t - 2; w = 134; h = 10 }

let icon_box t : F.t =
  {
    x = tile_x t - tg.icon_margin;
    y = tile_y t - tg.icon_margin;
    w = tg.tile_size + (2 * tg.icon_margin);
    h = tg.tile_size + (2 * tg.icon_margin);
  }

(* The list's light page above the game's card. *)
let page_id = "home.game_list_page"
let page : F.t = { x = 100; y = 200; w = 800; h = 40 }

let frame_color =
  { lo = { r = 200; g = 120; b = 0 }; hi = { r = 255; g = 210; b = 90 } }

let tile_probes ~game_icon t =
  [
    F.count_probe (frame_id t) (frame_box t) ~min:(rgb_tuple frame_color.lo)
      ~max:(rgb_tuple frame_color.hi);
    F.template_probe (icon_id t) (icon_box t) game_icon;
  ]

let probes ~game_icon =
  [
    F.count_probe menu_id menu_box ~min:(rgb_tuple orange.lo)
      ~max:(rgb_tuple orange.hi);
    F.stats_probe strip_id strip;
    F.stats_probe line1_id line1;
    F.stats_probe line2_id line2;
    F.stats_probe page_id page;
  ]
  @ List.concat_map (tile_probes ~game_icon) tiles

let min_menu_orange = 0.45

let holds m id test =
  Option.fold ~none:false ~some:test (Switch.Color_share.read m id)

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
