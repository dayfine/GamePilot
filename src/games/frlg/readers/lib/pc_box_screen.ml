let game_w = 240.
let game_h = 160.

let box ~x ~y ~w ~h : Wire.box =
  {
    x = float x /. game_w;
    y = float y /. game_h;
    w = float w /. game_w;
    h = float h /. game_h;
  }

let panel_id = "pc_box.panel"
let panel_box : Wire.box = { x = 0.007; y = 0.556; w = 0.296; h = 0.253 }
let min_panel_stddev = 10.
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

let probes =
  [
    Solid_color.probe ~id:panel_id panel_box;
    Color_count.probe ~id:shadow_id shadow_box shadow;
    Color_count.probe ~id:wallpaper_id wallpaper_box anything;
    Color_count.probe ~id:male_id male_box male_blue;
  ]

let panel_occupied m =
  Option.map
    (fun (s : Solid_color.stats) -> Solid_color.sum s.stddev > min_panel_stddev)
    (Solid_color.read m panel_id)

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
