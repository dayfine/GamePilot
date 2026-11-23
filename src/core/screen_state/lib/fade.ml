type t = No_fade | Black | White

let middle_box : Wire.box = { x = 0.1; y = 0.1; w = 0.8; h = 0.8 }
let max_stddev_sum = 10.
let max_dark_sum = 225.
let min_white_sum = 500.
let sum (c : Wire.rgb) = c.r +. c.g +. c.b

let of_color_stats ~mean ~stddev =
  if sum stddev > max_stddev_sum then No_fade
  else if sum mean <= max_dark_sum then Black
  else if sum mean >= min_white_sum then White
  else No_fade

let name = function
  | No_fade -> "no fade"
  | Black -> "black fade"
  | White -> "white fade"
