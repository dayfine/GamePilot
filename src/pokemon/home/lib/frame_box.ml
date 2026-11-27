type t = { x : int; y : int; w : int; h : int }

let frame_width = 1920.
let frame_height = 1080.

let box { x; y; w; h } : Wire.box =
  {
    x = float_of_int x /. frame_width;
    y = float_of_int y /. frame_height;
    w = float_of_int w /. frame_width;
    h = float_of_int h /. frame_height;
  }

let stats_probe id b = Wire.color_stats_probe ~id ~box:(box b) ~delivery:Every

let count_probe id b ~min ~max =
  Wire.color_count_probe ~id ~box:(box b) ~delivery:Every ~min ~max

let template_probe ?ink id b template =
  Wire.template_match_probe ?ink ~id ~box:(box b) ~delivery:Every ~template ()

let score m id =
  match Effects.probe m id with
  | Some (Wire.Template_match { score; x; _ }) -> Some (score, x *. frame_width)
  | Some
      ( Wire.Color_stats _ | Wire.Template_ncc _ | Wire.Color_count _
      | Wire.Line_shares _ | Wire.Find _ | Wire.Other _ )
  | None ->
      None
