let inside_id = "money.inside"
let left_id = "money.left"
let bottom_id = "money.bottom"
let inside = Game_pixels.box { x = 8.; y = 6.; w = 64.; h = 3. }
let left = Game_pixels.box { x = 3.; y = 6.; w = 1.; h = 26. }
let bottom = Game_pixels.box { x = 6.; y = 36.; w = 66.; h = 1. }

let probes =
  [
    Solid_color.probe ~id:inside_id inside;
    Solid_color.probe ~id:left_id left;
    Solid_color.probe ~id:bottom_id bottom;
  ]

let frame_min_sum = 270.
let frame_max_sum = 420.
let max_frame_stddev_sum = 40.

let grey m id =
  Solid_color.holds m id
    (Solid_color.is_grey ~min_sum:frame_min_sum ~max_sum:frame_max_sum
       ~max_stddev_sum:max_frame_stddev_sum)

let money_box m =
  Solid_color.holds m inside_id (fun s -> Solid_color.is_white s)
  && grey m left_id && grey m bottom_id
