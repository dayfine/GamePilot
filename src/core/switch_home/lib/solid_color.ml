type stats = { mean : Wire.rgb; stddev : Wire.rgb }

let stats m id =
  match Effects.probe m id with
  | Some (Wire.Color_stats { mean; stddev }) -> Some { mean; stddev }
  | Some (Wire.Template_match _ | Wire.Color_count _ | Wire.Other _) | None ->
      None

let sum (c : Wire.rgb) = c.r +. c.g +. c.b

let distance (a : Wire.rgb) (b : Wire.rgb) =
  let d x y = (x -. y) *. (x -. y) in
  Float.sqrt (d a.r b.r +. d a.g b.g +. d a.b b.b)

let solid_max_stddev = 10.
let white_max_distance = 0.08
let grey_max_distance = 0.1
let hue_min_sum = 100.
let white_min_sum = 500.
let channels = 3.

let share_distance (c : Wire.rgb) =
  let total = sum c in
  if total <= 0. then Float.infinity
  else
    let third = 1. /. channels in
    let d x = (x /. total) -. third in
    Float.sqrt ((d c.r *. d c.r) +. (d c.g *. d c.g) +. (d c.b *. d c.b))

let is_white s =
  sum s.mean >= white_min_sum
  && sum s.stddev <= solid_max_stddev
  && share_distance s.mean <= white_max_distance

let is_grey ~min_sum ~max_sum s =
  let total = sum s.mean in
  total >= min_sum && total <= max_sum
  && sum s.stddev <= solid_max_stddev
  && (total < hue_min_sum || share_distance s.mean <= grey_max_distance)
