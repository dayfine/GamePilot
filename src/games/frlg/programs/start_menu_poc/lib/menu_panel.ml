let probe_id = "menu_panel"

let probe =
  Wire.color_stats_probe ~id:probe_id
    ~box:{ x = 0.94; y = 0.05; w = 0.04; h = 0.5 }
    ~delivery:Every

(* The dev-loop knobs: the open panel measures about 248, with stddev under 7
   on mGBA and about 23 on console B's capture (scaling and JPEG-like noise);
   text-heavy white areas measure 40 and up. *)
let min_white = 220.
let max_stddev = 30.

let start_menu_open m =
  match Effects.probe m probe_id with
  | Some (Wire.Color_stats { mean; stddev }) ->
      Float.min mean.r (Float.min mean.g mean.b) >= min_white
      && Float.max stddev.r (Float.max stddev.g stddev.b) <= max_stddev
  | Some
      ( Wire.Template_match _ | Wire.Color_count _ | Wire.Line_shares _
      | Wire.Find _ | Wire.Other _ )
  | None ->
      false
