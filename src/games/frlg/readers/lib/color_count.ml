type channels = { r : int; g : int; b : int }
type range = { low : channels; high : channels }

let triple c = (c.r, c.g, c.b)

let probe ~id box range =
  Wire.color_count_probe ~id ~box ~delivery:Every ~min:(triple range.low)
    ~max:(triple range.high)

let share m id =
  match Effects.probe m id with
  | Some (Wire.Color_count { fraction; _ }) -> Some fraction
  | Some (Wire.Color_stats _ | Wire.Template_match _ | Wire.Other _) | None ->
      None
