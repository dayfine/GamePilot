type rect = { x : int; y : int; w : int; h : int }

(* Boxes here are stated in whole game pixels. *)
let box (r : rect) =
  Game_pixels.box { x = float r.x; y = float r.y; w = float r.w; h = float r.h }

let panel_id = "pc_box.panel"
let panel_box : Wire.box = { x = 0.007; y = 0.556; w = 0.296; h = 0.253 }
let min_panel_stddev = 10.
let item_id = "pc_box.item"
let item_box = box { x = 2; y = 134; w = 68; h = 10 }
let shadow_id = "pc_box.first_slot_shadow"
let shadow_box = box { x = 93; y = 49; w = 13; h = 7 }

let shadow : Color_count.range =
  { low = { r = 50; g = 75; b = 90 }; high = { r = 115; g = 140; b = 160 } }

let min_shadow_share = 0.25
let wallpaper_id = "pc_box.wallpaper"
let wallpaper_box = box { x = 100; y = 140; w = 120; h = 12 }

let anything : Color_count.range =
  { low = { r = 0; g = 0; b = 0 }; high = { r = 255; g = 255; b = 255 } }

let male_id = "pc_box.male"
let male_box = box { x = 9; y = 116; w = 9; h = 13 }

(* Core blue of the male mark is (0, 123, 255) on mGBA; the panel's lilac
   background is (148, 148, 173) (r >= 133 even at x0.9 brightness) and the
   female mark is red (173, 24, 24). Keeping r <= 100 and b >= 190 isolates
   the male mark with zero hits on lilac or female frames (#194). *)
let male_blue : Color_count.range =
  { low = { r = 0; g = 0; b = 190 }; high = { r = 100; g = 210; b = 255 } }

let min_male_share = 0.15
let min_red_over_green = 15.
let min_green_over_blue = 20.

(* The title menu's arrow: x 145-149, a row's glyph rows (y 58 + 16 i). *)
type title_menu_geom = {
  rows : int;
  left : int;
  width : int;
  first_top : int;
  pitch : int;
  height : int;
}

let title_geom =
  { rows = 4; left = 143; width = 9; first_top = 59; pitch = 16; height = 11 }

let title_menu_box i =
  box
    {
      x = title_geom.left;
      y = title_geom.first_top + (title_geom.pitch * i);
      w = title_geom.width;
      h = title_geom.height;
    }

let title_menu =
  Cursor_column.make ~prefix:"pc_box.title_menu"
    (List.init title_geom.rows title_menu_box)

let title_menu_row m = Cursor_column.row title_menu m

(* The hand over the first slot, x 90-105, y 20-37 (its bob included). *)
let hand_id = "pc_box.hand_first_slot"
let hand_box = box { x = 90; y = 20; w = 16; h = 18 }

let quick_yellow : Color_count.range =
  { low = { r = 225; g = 200; b = 40 }; high = { r = 255; g = 255; b = 150 } }

let min_quick_share = 0.12

let hand_quick m =
  Option.map (fun s -> s >= min_quick_share) (Color_count.share m hand_id)

(* The title bar's wallpaper, right of the hand when it points at the title
   (x 137-156) and of most of the name: its sky above the name (y 20-22) and
   its ground below it (y 34-35), x 162-193. *)
let title_sky_id = "pc_box.title_sky"
let title_ground_id = "pc_box.title_ground"
let title_sky_box = box { x = 162; y = 20; w = 32; h = 3 }
let title_ground_box = box { x = 162; y = 34; w = 32; h = 2 }

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
