let star_id = "summary.shiny_star"

(* ShinySymbolDetector's m_box_symbol. *)
let star_box : Wire.box =
  { x = 0.421231; y = 0.214308; w = 0.0406154; h = 0.0623077 }

let star : Color_count.range =
  { low = { r = 193; g = 152; b = 0 }; high = { r = 255; g = 255; b = 162 } }

let min_red_over_blue = 20.
let probes = [ Color_count.probe ~id:star_id star_box star ]

let shiny m =
  match Color_count.mean m star_id with
  | Some (c : Wire.rgb) -> c.b +. min_red_over_blue < c.r
  | None -> false
