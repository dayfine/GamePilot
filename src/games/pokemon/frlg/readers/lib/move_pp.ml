let pp_id = "battle.pp"

(* The PP line of the PP box, x 166-232, y 121-135 in game pixels. *)
let pp_line : Wire.box =
  { x = 0.692901; y = 0.758376; w = 0.275753; h = 0.085431 }

let empty_red : Color_count.range =
  { low = { r = 180; g = 0; b = 0 }; high = { r = 255; g = 120; b = 120 } }

let min_red_share = 0.01
let probes = [ Color_count.probe ~id:pp_id pp_line empty_red ]

let no_pp_left m =
  Battle_screen.move_menu m
  &&
  match Color_count.share m pp_id with
  | Some share -> share > min_red_share
  | None -> false
