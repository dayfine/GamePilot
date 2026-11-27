type channels = { r : int; g : int; b : int }
type range = { low : channels; high : channels }

let triple c = (c.r, c.g, c.b)

let probe ~id box range =
  Wire.color_count_probe ~id ~box ~delivery:Every ~min:(triple range.low)
    ~max:(triple range.high)

let share = Switch.Color_share.read

let mean m id =
  match Effects.probe m id with
  | Some (Wire.Color_count { mean; _ }) -> mean
  | _ -> None

let red_excess (c : Wire.rgb) = Float.min (c.r -. c.g) (c.r -. c.b)
