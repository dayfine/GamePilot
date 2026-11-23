let arrow_id = "battle.arrow"

let text_box : Wire.box =
  { x = 0.036; y = 0.748077; w = 0.926769; h = 0.204577 }

let arrow : Color_count.range =
  { low = { r = 164; g = 0; b = 0 }; high = { r = 255; g = 114; b = 87 } }

let min_red_excess = 180.
let probes = [ Color_count.probe ~id:arrow_id text_box arrow ]

let red_arrow m =
  match Color_count.mean m arrow_id with
  | Some mean -> Color_count.red_excess mean > min_red_excess
  | None -> false

let advance_arrow m =
  (Battle_screen.battle_text_box m || Battle_screen.level_up_box m)
  && red_arrow m
