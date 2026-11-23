let probe_id = "menu_panel"

let probe : Wire.probe_spec =
  {
    id = probe_id;
    kind = "core.color_stats@1";
    box = { x = 0.94; y = 0.05; w = 0.04; h = 0.5 };
    delivery = Every;
  }

(* The dev-loop knobs: the open panel measures about 248 with stddev under 7. *)
let min_white = 220.
let max_stddev = 20.

let start_menu_open m =
  match Kernel.probe m probe_id with
  | Some (Wire.Color_stats { mean; stddev }) ->
      Float.min mean.r (Float.min mean.g mean.b) >= min_white
      && Float.max stddev.r (Float.max stddev.g stddev.b) <= max_stddev
  | Some (Wire.Other _) | None -> false
