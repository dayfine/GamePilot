type stats = { mean : Wire.rgb; stddev : Wire.rgb }

let read m id =
  match Effects.probe m id with
  | Some (Wire.Color_stats { mean; stddev }) -> Some { mean; stddev }
  | Some (Wire.Template_match _ | Wire.Other _) | None -> None

let holds m id test = Option.fold ~none:false ~some:test (read m id)
let sum (c : Wire.rgb) = c.r +. c.g +. c.b

let ratio_distance (mean : Wire.rgb) (ratio : Wire.rgb) =
  let total = sum mean in
  if total <= 0. then Float.infinity
  else
    let d share expected = (share /. total) -. expected in
    let dr = d mean.r ratio.r
    and dg = d mean.g ratio.g
    and db = d mean.b ratio.b in
    Float.sqrt ((dr *. dr) +. (dg *. dg) +. (db *. db))

let is_solid ~ratio ~max_distance ~max_stddev_sum s =
  sum s.stddev <= max_stddev_sum && ratio_distance s.mean ratio <= max_distance

let channels = 3.
let third = 1. /. channels
let neutral : Wire.rgb = { r = third; g = third; b = third }

(* SolidColorTest's defaults. *)
let white_max_distance = 0.08
let grey_max_distance = 0.1
let hue_min_sum = 100.

let is_white ?(min_sum = 500.) ?(max_stddev_sum = 10.) s =
  sum s.mean >= min_sum
  && is_solid ~ratio:neutral ~max_distance:white_max_distance ~max_stddev_sum s

let is_grey ~min_sum ~max_sum ~max_stddev_sum s =
  let total = sum s.mean in
  total >= min_sum && total <= max_sum
  && sum s.stddev <= max_stddev_sum
  && (total < hue_min_sum || ratio_distance s.mean neutral <= grey_max_distance)
