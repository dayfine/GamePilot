let top_bar_id = "pokedex.top_bar"
let bottom_bar_id = "pokedex.bottom_bar"
let panel_id = "pokedex.panel"
let contents_arrow_id = "pokedex.contents_arrow"
let caught_id row = Printf.sprintf "pokedex.caught%d" row

(* (198, 181, 140) over its sum. *)
let tan : Wire.rgb = { r = 0.381; g = 0.349; b = 0.270 }
let max_tan_distance = 0.04
let max_bar_stddev_sum = 15.
let min_panel_channel = 190.
let max_panel_stddev_sum = 40.
let min_arrow_share = 0.12
let red_low = 160
let red_high = 100
let min_caught_share = 0.15

(* The list's rows: 9, 14 apart from y 18. *)
let rows = 9
let first_row_top = 18.
let row_pitch = 14.
let row_top row = first_row_top +. (row_pitch *. float_of_int row)
let top_bar = Game_pixels.box { x = 0.; y = 0.; w = 80.; h = 4. }
let bottom_bar = Game_pixels.box { x = 0.; y = 148.; w = 60.; h = 10. }
let panel = Game_pixels.box { x = 206.; y = 40.; w = 30.; h = 90. }

(* NUMERICAL MODE's row of the table of contents: its arrow at x 13 to 17, y
   34 to 42. *)
let contents_arrow = Game_pixels.box { x = 12.; y = 33.; w = 8.; h = 11. }

(* The list's arrow at x 21 to 26, left of the No symbol at x 28. *)
let arrow_box row =
  Game_pixels.box { x = 19.; y = row_top row +. 1.; w = 8.; h = 12. }

let ball_box row =
  Game_pixels.box { x = 56.; y = row_top row; w = 12.; h = 12. }

let arrows =
  Cursor_column.make ~prefix:"pokedex.list" (List.init rows arrow_box)

let dark : Color_count.range =
  {
    low = { r = 0; g = 0; b = 0 };
    high =
      {
        r = Cursor_column.dark_max;
        g = Cursor_column.dark_max;
        b = Cursor_column.dark_max;
      };
  }

let red : Color_count.range =
  {
    low = { r = red_low; g = 0; b = 0 };
    high = { r = 255; g = red_high; b = red_high };
  }

let probes =
  [
    Solid_color.probe ~id:top_bar_id top_bar;
    Solid_color.probe ~id:bottom_bar_id bottom_bar;
    Solid_color.probe ~id:panel_id panel;
    Color_count.probe ~id:contents_arrow_id contents_arrow dark;
  ]
  @ Cursor_column.probes arrows
  @ List.init rows (fun row ->
        Color_count.probe ~id:(caught_id row) (ball_box row) red)

let bar m id =
  Solid_color.holds m id
    (Solid_color.is_solid ~ratio:tan ~max_distance:max_tan_distance
       ~max_stddev_sum:max_bar_stddev_sum)

let bars m = bar m top_bar_id && bar m bottom_bar_id

let plain_panel (s : Solid_color.stats) =
  Float.min s.mean.r (Float.min s.mean.g s.mean.b) >= min_panel_channel
  && Solid_color.sum s.stddev <= max_panel_stddev_sum

let share_at_least m id min =
  match Color_count.share m id with Some s -> s >= min | None -> false

let contents_shown m =
  bars m
  && (not (Solid_color.holds m panel_id plain_panel))
  && share_at_least m contents_arrow_id min_arrow_share

let list_shown m = bars m && Solid_color.holds m panel_id plain_panel
let cursor_row m = if list_shown m then Cursor_column.row arrows m else None

let caught m row =
  list_shown m && share_at_least m (caught_id row) min_caught_share
