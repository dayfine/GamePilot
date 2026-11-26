module PB = Switch_home.Picture_box
module CS = Switch_home.Color_share

type nearby = { north_east : bool; south_east : bool }

let id_ne = "bdsp_minimap_sparkle_ne"
let id_se = "bdsp_minimap_sparkle_se"

let box_ne : Wire.box = { x = 0.095; y = 0.090; w = 0.035; h = 0.065 }
let box_se : Wire.box = { x = 0.095; y = 0.155; w = 0.035; h = 0.085 }

let orange_r_min = 200
let orange_g_min = 110
let orange_b_min = 0
let orange_r_max = 255
let orange_g_max = 215
let orange_b_max = 80
let orange_min = (orange_r_min, orange_g_min, orange_b_min)
let orange_max = (orange_r_max, orange_g_max, orange_b_max)

(* At 1920x1080 a single orange diamond is ~12-30 pixels out of ~4700-6200 in
   the strip (~0.002-0.006 share); 0.001 catches 1+ diamond while ignoring 0. *)
let min_sparkle_share = 0.001

let make_probe ~picture ~id box =
  Option.map
    (fun box ->
      Wire.color_count_probe ~id ~box ~min:orange_min ~max:orange_max
        ~delivery:Every)
    (PB.clipped ~picture box)

let probes ~picture =
  List.filter_map Fun.id
    [ make_probe ~picture ~id:id_ne box_ne; make_probe ~picture ~id:id_se box_se ]

let has_sparkle m id =
  match CS.read m id with
  | Some share -> share >= min_sparkle_share
  | None -> false

let read m =
  { north_east = has_sparkle m id_ne; south_east = has_sparkle m id_se }

let any n = n.north_east || n.south_east
