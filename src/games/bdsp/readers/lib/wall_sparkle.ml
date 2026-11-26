open Bdsp_underground
module PB = Switch_home.Picture_box
module CS = Switch_home.Color_share

let id_north = "bdsp_wall_sparkle_n"
let id_south = "bdsp_wall_sparkle_s"
let id_east = "bdsp_wall_sparkle_e"
let id_west = "bdsp_wall_sparkle_w"

(* Four wall strips around the centered player, excluding top-left minimap. *)
let box_north : Wire.box = { x = 0.30; y = 0.14; w = 0.40; h = 0.34 }
let box_south : Wire.box = { x = 0.30; y = 0.52; w = 0.40; h = 0.30 }
let box_east : Wire.box = { x = 0.54; y = 0.24; w = 0.28; h = 0.52 }
let box_west : Wire.box = { x = 0.25; y = 0.24; w = 0.22; h = 0.52 }
let star_r_min = 200
let star_g_min = 0
let star_b_min = 200
let star_r_max = 255
let star_g_max = 185
let star_b_max = 255
let star_min = (star_r_min, star_g_min, star_b_min)
let star_max = (star_r_max, star_g_max, star_b_max)
let min_star_share = 0.0004

let dirs =
  [
    (Corridor_nav.North, id_north, box_north);
    (Corridor_nav.South, id_south, box_south);
    (Corridor_nav.East, id_east, box_east);
    (Corridor_nav.West, id_west, box_west);
  ]

let make_probe ~picture (_, id, box) =
  Option.map
    (fun b ->
      Wire.color_count_probe ~id ~box:b ~min:star_min ~max:star_max
        ~delivery:Every)
    (PB.clipped ~picture box)

let probes ~picture = List.filter_map (make_probe ~picture) dirs

let direction m =
  let best =
    List.fold_left
      (fun acc (dir, id, _) ->
        let s = Option.value (CS.read m id) ~default:0. in
        match acc with
        | None when s >= min_star_share -> Some (dir, s)
        | Some (_, bs) when s > bs -> Some (dir, s)
        | _ -> acc)
      None dirs
  in
  Option.map fst best
