open Solid_color

type game = { key : string; icon : Effects.template_hash }

let frame_width = 1920.
let frame_height = 1080.

(* A box given in the 1920x1080 frame's pixels, normalized. *)
let pixels ({ x; y; w; h } : Wire.box) : Wire.box =
  {
    x = x /. frame_width;
    y = y /. frame_height;
    w = w /. frame_width;
    h = h /. frame_height;
  }

(* The game page: the top edge of "Delete Save Data for <user>"'s blue frame
   (y 174..180; on Manage Software's page the row's frame starts at 210). The
   icon: 90 px at (90, 30), searched 10 px round. *)
let row_top_id = "delete_save.row_top"
let row_top = pixels { x = 300.; y = 175.; w = 800.; h = 4. }
let icon_box = pixels { x = 80.; y = 20.; w = 110.; h = 110. }
let icon_id key = "delete_save.icon." ^ key

(* Caution: inside the red button (705..822 high) left of its text, and the top
   edge of the blue frame round it (y 694..700). Deleted: the top edge of the
   OK button's blue frame (y 745..751), inside the button, and the message's
   row. *)
let red_fill_id = "delete_save.red_fill"
let red_fill = pixels { x = 480.; y = 712.; w = 280.; h = 106. }
let red_frame_id = "delete_save.red_frame"
let red_frame = pixels { x = 480.; y = 695.; w = 960.; h = 4. }
let ok_frame_id = "delete_save.ok_frame"
let ok_frame = pixels { x = 480.; y = 746.; w = 960.; h = 4. }
let ok_fill_id = "delete_save.ok_fill"
let ok_fill = pixels { x = 480.; y = 770.; w = 400.; h = 80. }
let message_id = "delete_save.message"
let message = pixels { x = 670.; y = 475.; w = 580.; h = 45. }

let icon_probe game =
  Wire.template_match_probe ~id:(icon_id game.key) ~box:icon_box ~delivery:Every
    ~template:game.icon ()

let colour_probes =
  List.map
    (fun (id, box) -> Wire.color_stats_probe ~id ~box ~delivery:Every)
    [
      (row_top_id, row_top);
      (red_fill_id, red_fill);
      (red_frame_id, red_frame);
      (ok_frame_id, ok_frame);
      (ok_fill_id, ok_fill);
      (message_id, message);
    ]

(* Headroom on console B's captures (test/images/delete-save, with their
   shifted versions): the three blue frame edges read blue minus red 184 at
   least (166 shifted) against 100, green minus red 130 (117) against 60, and
   stddevs 25 (28) against 50; every other box's blue minus red is 29 at most.
   The red button reads red minus green 197 (177 shifted) against 120, red
   minus blue 255 (229) against 150, stddev 0 against 30; every other box's red
   minus green is 12 at most. Inside the OK button sums 114 (102 to 141
   shifted) against 200, stddev 1 against 20; the message row's stddev is 198
   (178) against 100. Z-A's icon scores 0.0021 at most on its pages, shifted,
   against 0.02, and 0.043 at least on every other capture. FireRed's icon,
   made from the game list's (no FireRed page was captured), is untested on
   its own page: Z-A's icon made the same way scores 0.0054 on Z-A's page. *)
let blue_min_over_red = 100.
let green_min_over_red = 60.
let edge_max_stddev = 50.
let red_min_over_green = 120.
let red_min_over_blue = 150.
let fill_max_stddev = 30.
let ok_max_sum = 200.
let ok_max_stddev = 20.
let message_min_stddev = 100.
let max_icon_score = 0.02

let blue_edge s =
  s.mean.b -. s.mean.r >= blue_min_over_red
  && s.mean.g -. s.mean.r >= green_min_over_red
  && sum s.stddev <= edge_max_stddev

let red s =
  s.mean.r -. s.mean.g >= red_min_over_green
  && s.mean.r -. s.mean.b >= red_min_over_blue
  && sum s.stddev <= fill_max_stddev

let holds test m id = Option.fold ~none:false ~some:test (stats m id)
let game_page m = holds blue_edge m row_top_id

let is_game key m =
  match Effects.probe m (icon_id key) with
  | Some (Wire.Template_match { score; _ }) -> score <= max_icon_score
  | Some
      ( Wire.Color_stats _ | Wire.Color_count _ | Wire.Line_shares _
      | Wire.Find _ | Wire.Other _ )
  | None ->
      false

type caution = Red_selected | Red_not_selected | No_red_button

let caution m =
  if not (holds red m red_fill_id) then No_red_button
  else if holds blue_edge m red_frame_id then Red_selected
  else Red_not_selected

let caution_to_string = function
  | Red_selected -> "the red button, selected"
  | Red_not_selected -> "the red button, not selected"
  | No_red_button -> "no red button"

let dark_flat s = sum s.mean <= ok_max_sum && sum s.stddev <= ok_max_stddev

let deleted m =
  holds blue_edge m ok_frame_id
  && holds dark_flat m ok_fill_id
  && holds (fun s -> sum s.stddev >= message_min_stddev) m message_id
