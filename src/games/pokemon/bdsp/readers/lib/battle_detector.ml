module PB = Switch.Picture_box
module SC = Switch.Solid_color

let id_battle = "bdsp_battle_menu_fight"
let id_run = "bdsp_battle_menu_run"
let box_battle : Wire.box = { x = 0.817; y = 0.585; w = 0.150; h = 0.070 }
let box_run : Wire.box = { x = 0.817; y = 0.9075; w = 0.150; h = 0.070 }
let min_stddev = 30.
let max_stddev = 150.
let fight_r = 0.541961
let fight_g = 0.231317
let fight_b = 0.226722
let run_r = 0.19
let run_g = 0.36
let run_b = 0.45
let max_dist = 0.18

let color_probe ~picture ~id box =
  Option.map
    (fun box -> Wire.color_stats_probe ~id ~box ~delivery:Every)
    (PB.clipped ~picture box)

let probes ~picture =
  List.filter_map Fun.id
    [
      color_probe ~picture ~id:id_battle box_battle;
      color_probe ~picture ~id:id_run box_run;
    ]

let matches_button m id (tr, tg, tb) =
  match SC.stats m id with
  | None -> false
  | Some s ->
      let sd = SC.sum s.stddev in
      let avg_sum = SC.sum s.mean in
      if sd < min_stddev || sd > max_stddev || avg_sum <= 0. then false
      else
        let dr = (s.mean.r /. avg_sum) -. tr in
        let dg = (s.mean.g /. avg_sum) -. tg in
        let db = (s.mean.b /. avg_sum) -. tb in
        sqrt ((dr *. dr) +. (dg *. dg) +. (db *. db)) <= max_dist

let shown m =
  matches_button m id_battle (fight_r, fight_g, fight_b)
  && matches_button m id_run (run_r, run_g, run_b)
