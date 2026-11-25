module Solid_color = Switch_home.Solid_color

type stats = Solid_color.stats

let probe ~picture ~id box =
  Option.to_list
    (Option.map
       (fun box -> Wire.color_stats_probe ~id ~box ~delivery:Every)
       (Native_box.probe_box ~picture box))

let read = Solid_color.stats

let is_solid ~ratio ~max_distance ~max_stddev_sum (s : stats) =
  let total = Solid_color.sum s.mean in
  let shares : Wire.rgb =
    { r = s.mean.r /. total; g = s.mean.g /. total; b = s.mean.b /. total }
  in
  Solid_color.sum s.stddev <= max_stddev_sum
  && Solid_color.distance shares ratio <= max_distance

(* Grey: a third each, within 0.08. *)
let grey : Wire.rgb = { r = 0.333333; g = 0.333333; b = 0.333333 }
let white_max_distance = 0.08

let is_white ~min_sum ~max_stddev_sum (s : stats) =
  Solid_color.sum s.mean >= min_sum
  && is_solid ~ratio:grey ~max_distance:white_max_distance ~max_stddev_sum s
