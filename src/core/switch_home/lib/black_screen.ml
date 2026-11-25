open Solid_color

let id = "start_game.black"
let frame_box : Wire.box = { x = 0.1; y = 0.15; w = 0.8; h = 0.7 }
let max_rgb_sum = 100.
let max_stddev_sum = 10.

let probes ~picture =
  Option.to_list
    (Option.map
       (fun box -> Wire.color_stats_probe ~id ~box ~delivery:Every)
       (Picture_box.clipped ~picture frame_box))

let shown m =
  match stats m id with
  | Some s -> sum s.mean <= max_rgb_sum && sum s.stddev <= max_stddev_sum
  | None -> false
