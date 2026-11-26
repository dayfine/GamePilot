(* Boxes here are stated in whole game pixels. *)
let box ~x ~y ~w ~h =
  Game_pixels.box { x = float x; y = float y; w = float w; h = float h }

let panel_id = "pc_box.panel"
let panel_box : Wire.box = { x = 0.007; y = 0.556; w = 0.296; h = 0.253 }
let min_panel_stddev = 10.
let item_id = "pc_box.item"
let item_x = 2
let item_y = 134
let item_w = 68
let item_h = 10
let item_box = box ~x:item_x ~y:item_y ~w:item_w ~h:item_h
let shadow_id = "pc_box.first_slot_shadow"
let shadow_x = 93
let shadow_y = 49
let shadow_w = 13
let shadow_h = 7
let shadow_box = box ~x:shadow_x ~y:shadow_y ~w:shadow_w ~h:shadow_h

let shadow : Color_count.range =
  { low = { r = 50; g = 75; b = 90 }; high = { r = 115; g = 140; b = 160 } }

let min_shadow_share = 0.25
let wallpaper_id = "pc_box.wallpaper"
let wallpaper_x = 100
let wallpaper_y = 140
let wallpaper_w = 120
let wallpaper_h = 12

let wallpaper_box =
  box ~x:wallpaper_x ~y:wallpaper_y ~w:wallpaper_w ~h:wallpaper_h

let anything : Color_count.range =
  { low = { r = 0; g = 0; b = 0 }; high = { r = 255; g = 255; b = 255 } }

let male_id = "pc_box.male"
let male_x = 9
let male_y = 116
let male_w = 9
let male_h = 13
let male_box = box ~x:male_x ~y:male_y ~w:male_w ~h:male_h

let male_blue : Color_count.range =
  { low = { r = 0; g = 0; b = 170 }; high = { r = 150; g = 210; b = 255 } }

let min_male_share = 0.15
let min_red_over_green = 15.
let min_green_over_blue = 20.

(* The title menu's arrow: x 145-149, a row's glyph rows (y 58 + 16 i). *)
let title_menu_rows = 4
let title_menu_arrow_left = 143
let title_menu_arrow_width = 9
let title_menu_first_top = 59
let title_menu_pitch = 16
let title_menu_arrow_height = 11

let title_menu_box i =
  box ~x:title_menu_arrow_left
    ~y:(title_menu_first_top + (title_menu_pitch * i))
    ~w:title_menu_arrow_width ~h:title_menu_arrow_height

let title_menu =
  Cursor_column.make ~prefix:"pc_box.title_menu"
    (List.init title_menu_rows title_menu_box)

let title_menu_row m = Cursor_column.row title_menu m

(* The hand over the first slot, x 90-105, y 20-37 (its bob included). *)
let hand_id = "pc_box.hand_first_slot"
let hand_left = 90
let hand_top = 20
let hand_width = 16
let hand_height = 18
let hand_box = box ~x:hand_left ~y:hand_top ~w:hand_width ~h:hand_height

let quick_yellow : Color_count.range =
  { low = { r = 225; g = 200; b = 40 }; high = { r = 255; g = 255; b = 150 } }

let min_quick_share = 0.12

let hand_quick m =
  Option.map (fun s -> s >= min_quick_share) (Color_count.share m hand_id)

(* The title bar's wallpaper, right of the hand when it points at the title
   (x 137-156) and of most of the name: its sky above the name (y 20-22) and
   its ground below it (y 34-35), x 162-193. *)
let title_left = 162
let title_width = 32
let title_sky_id = "pc_box.title_sky"
let title_sky_y = 20
let title_sky_h = 3
let title_ground_id = "pc_box.title_ground"
let title_ground_y = 34
let title_ground_h = 2

let title_sky_box =
  box ~x:title_left ~y:title_sky_y ~w:title_width ~h:title_sky_h

let title_ground_box =
  box ~x:title_left ~y:title_ground_y ~w:title_width ~h:title_ground_h

let probes =
  Cursor_column.probes title_menu
  @ [
      Solid_color.probe ~id:panel_id panel_box;
      Solid_color.probe ~id:item_id item_box;
      Color_count.probe ~id:shadow_id shadow_box shadow;
      Color_count.probe ~id:wallpaper_id wallpaper_box anything;
      Color_count.probe ~id:male_id male_box male_blue;
      Color_count.probe ~id:hand_id hand_box quick_yellow;
      Solid_color.probe ~id:title_sky_id title_sky_box;
      Solid_color.probe ~id:title_ground_id title_ground_box;
    ]

let panel_occupied m =
  Option.map
    (fun (s : Solid_color.stats) -> Solid_color.sum s.stddev > min_panel_stddev)
    (Solid_color.read m panel_id)

let holds_item m =
  Option.map
    (fun (s : Solid_color.stats) -> Solid_color.sum s.stddev > min_panel_stddev)
    (Solid_color.read m item_id)

let hand_on_first_slot m =
  Option.map (fun s -> s >= min_shadow_share) (Color_count.share m shadow_id)

let desert_wallpaper m =
  Option.map
    (fun (c : Wire.rgb) ->
      c.r -. c.g >= min_red_over_green && c.g -. c.b >= min_green_over_blue)
    (Color_count.mean m wallpaper_id)

let male m =
  Option.map (fun s -> s >= min_male_share) (Color_count.share m male_id)

let min_green_over_red = 20.

let forest_wallpaper m =
  Option.map
    (fun (c : Wire.rgb) ->
      c.g -. c.r >= min_green_over_red && c.g -. c.b >= min_green_over_red)
    (Color_count.mean m wallpaper_id)

type wallpaper = Forest | City | Desert | Savanna

let default_wallpapers = [ Forest; City; Desert; Savanna ]

let default_wallpaper box =
  match (box - 1) mod List.length default_wallpapers with
  | 0 -> Forest
  | 1 -> City
  | 2 -> Desert
  | _ -> Savanna

let wallpaper_name = function
  | Forest -> "Forest"
  | City -> "City"
  | Desert -> "Desert"
  | Savanna -> "Savanna"

(* The title bar's sky and ground, the mean of the mGBA and Switch frames
   (box-titles fixtures, 2026-11-25). *)
let forest_sky : Wire.rgb = { r = 205.; g = 252.; b = 176. }
let forest_ground : Wire.rgb = { r = 169.; g = 168.; b = 114. }
let city_sky : Wire.rgb = { r = 87.; g = 136.; b = 207. }
let city_ground : Wire.rgb = { r = 173.; g = 191.; b = 194. }
let desert_sky : Wire.rgb = { r = 175.; g = 168.; b = 173. }
let desert_ground : Wire.rgb = { r = 69.; g = 70.; b = 69. }
let savanna_sky : Wire.rgb = { r = 189.; g = 209.; b = 225. }
let savanna_ground : Wire.rgb = { r = 160.; g = 169.; b = 34. }

let title_colors = function
  | Forest -> (forest_sky, forest_ground)
  | City -> (city_sky, city_ground)
  | Desert -> (desert_sky, desert_ground)
  | Savanna -> (savanna_sky, savanna_ground)

let max_wallpaper_distance = 50.

let distance (a : Wire.rgb) (b : Wire.rgb) =
  Float.sqrt
    (((a.r -. b.r) ** 2.) +. ((a.g -. b.g) ** 2.) +. ((a.b -. b.b) ** 2.))

let shows (sky : Wire.rgb) (ground : Wire.rgb) w =
  let want_sky, want_ground = title_colors w in
  distance sky want_sky <= max_wallpaper_distance
  && distance ground want_ground <= max_wallpaper_distance

let title_wallpaper m =
  match
    (Solid_color.read m title_sky_id, Solid_color.read m title_ground_id)
  with
  | Some sky, Some ground ->
      List.find_opt (shows sky.mean ground.mean) default_wallpapers
  | _ -> None
