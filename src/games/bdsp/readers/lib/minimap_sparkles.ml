module PB = Switch_home.Picture_box
module CS = Switch_home.Color_share

type nearby = { bottom_east : bool; east_vertical : bool; top_east : bool }

let none = { bottom_east = false; east_vertical = false; top_east = false }
let id_bottom_east = "bdsp_minimap_sparkle_bottom_east"
let id_east_vertical = "bdsp_minimap_sparkle_east_vertical"
let id_top_east = "bdsp_minimap_sparkle_top_east"

(* Measured from run-39/000024.jpg and run-42/000300.jpg:
   Player dot at South doorway: x=0.095..0.111, y=0.144..0.156
   bottom_east sparkles:        x=0.122..0.133, y=0.144..0.147
   east_vertical sparkles:      x=0.136..0.139, y=0.106..0.111
   top_east sparkles:           x=0.128..0.133, y=0.067..0.078 *)
let box_bottom_east : Wire.box = { x = 0.114; y = 0.138; w = 0.032; h = 0.022 }

let box_east_vertical : Wire.box =
  { x = 0.128; y = 0.082; w = 0.022; h = 0.056 }

let box_top_east : Wire.box = { x = 0.100; y = 0.055; w = 0.048; h = 0.027 }
let orange_r_min = 200
let orange_g_min = 110
let orange_b_min = 0
let orange_r_max = 255
let orange_g_max = 215
let orange_b_max = 80
let orange_min = (orange_r_min, orange_g_min, orange_b_min)
let orange_max = (orange_r_max, orange_g_max, orange_b_max)

(* At 640x360 a single orange diamond is ~2-6 pixels out of ~150-300 in a tight
   corridor strip (~0.008-0.025 share); 0.003 catches 1+ diamond cleanly. *)
let min_sparkle_share = 0.003

let make_probe ~picture ~id box =
  Option.map
    (fun box ->
      Wire.color_count_probe ~id ~box ~min:orange_min ~max:orange_max
        ~delivery:Every)
    (PB.clipped ~picture box)

let probes ~picture =
  List.filter_map Fun.id
    [
      make_probe ~picture ~id:id_bottom_east box_bottom_east;
      make_probe ~picture ~id:id_east_vertical box_east_vertical;
      make_probe ~picture ~id:id_top_east box_top_east;
    ]

let has_sparkle m id =
  match CS.read m id with
  | Some share -> share >= min_sparkle_share
  | None -> false

let read m =
  {
    bottom_east = has_sparkle m id_bottom_east;
    east_vertical = has_sparkle m id_east_vertical;
    top_east = has_sparkle m id_top_east;
  }

let any n = n.bottom_east || n.east_vertical || n.top_east

let to_string n =
  let parts =
    (if n.bottom_east then [ "bottom_east" ] else [])
    @ (if n.east_vertical then [ "east_vertical" ] else [])
    @ if n.top_east then [ "top_east" ] else []
  in
  match parts with [] -> "none" | xs -> String.concat ", " xs
