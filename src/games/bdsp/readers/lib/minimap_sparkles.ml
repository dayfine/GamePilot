module PB = Switch_home.Picture_box
module CS = Switch_home.Color_share

type nearby = { east_corridor : bool; north_corridor : bool }

let id_east = "bdsp_minimap_sparkle_east"
let id_north = "bdsp_minimap_sparkle_north"

(* Measured from run-39/000024.jpg:
   East corridor sparkle:  x=0.1266, y=0.1444..0.1472
   North corridor sparkle: x=0.1359..0.1391, y=0.1056..0.1111 *)
let box_east : Wire.box = { x = 0.105; y = 0.138; w = 0.043; h = 0.024 }
let box_north : Wire.box = { x = 0.128; y = 0.075; w = 0.022; h = 0.063 }
let orange_r_min = 200
let orange_g_min = 110
let orange_b_min = 0
let orange_r_max = 255
let orange_g_max = 215
let orange_b_max = 80
let orange_min = (orange_r_min, orange_g_min, orange_b_min)
let orange_max = (orange_r_max, orange_g_max, orange_b_max)

(* At 640x360 a single orange diamond is ~2-6 pixels out of ~250-350 in a tight
   corridor strip (~0.005-0.020 share); 0.002 catches 1+ diamond cleanly. *)
let min_sparkle_share = 0.002

let make_probe ~picture ~id box =
  Option.map
    (fun box ->
      Wire.color_count_probe ~id ~box ~min:orange_min ~max:orange_max
        ~delivery:Every)
    (PB.clipped ~picture box)

let probes ~picture =
  List.filter_map Fun.id
    [
      make_probe ~picture ~id:id_east box_east;
      make_probe ~picture ~id:id_north box_north;
    ]

let has_sparkle m id =
  match CS.read m id with
  | Some share -> share >= min_sparkle_share
  | None -> false

let read m =
  {
    east_corridor = has_sparkle m id_east;
    north_corridor = has_sparkle m id_north;
  }

let any n = n.east_corridor || n.north_corridor
