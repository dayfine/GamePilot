open Bdsp_underground
module PB = Switch_home.Picture_box
module CS = Switch_home.Color_share

type offset = { dx : int; dy : int }

(* 3x3 screen grid around the player (x=0.50, y=0.48), excluding the top-left
   minimap (x<0.24, y<0.34). Row 0 starts at y=0.06 so North-wall stars remain
   inside row 0 even when the player hugs the South wall. *)
let col_left_x = 0.25
let col_left_w = 0.17
let col_mid_x = 0.42
let col_mid_w = 0.16
let col_right_x = 0.58
let col_right_w = 0.26
let row_top_y = 0.06
let row_top_h = 0.30
let row_mid_y = 0.36
let row_mid_h = 0.22
let row_bot_y = 0.58
let row_bot_h = 0.28

let col_bounds =
  [|
    (col_left_x, col_left_w); (col_mid_x, col_mid_w); (col_right_x, col_right_w);
  |]

let row_bounds =
  [| (row_top_y, row_top_h); (row_mid_y, row_mid_h); (row_bot_y, row_bot_h) |]

let star_r_min = 240
let star_g_min = 245
let star_b_min = 235
let star_r_max = 255
let star_g_max = 255
let star_b_max = 255
let star_min = (star_r_min, star_g_min, star_b_min)
let star_max = (star_r_max, star_g_max, star_b_max)
let min_star_share = 0.0014
let min_diff_share = 0.0008
let cell_id ci ri = Printf.sprintf "bdsp_wall_star_%d_%d" ci ri

let all_cells =
  List.concat_map (fun ri -> List.init 3 (fun ci -> (ci, ri))) [ 0; 1; 2 ]

let cell_box ci ri : Wire.box =
  let x, w = col_bounds.(ci) in
  let y, h = row_bounds.(ri) in
  { x; y; w; h }

let make_probe ~picture (ci, ri) =
  Option.map
    (fun b ->
      Wire.color_count_probe ~id:(cell_id ci ri) ~box:b ~min:star_min
        ~max:star_max ~delivery:Every)
    (PB.clipped ~picture (cell_box ci ri))

let probes ~picture = List.filter_map (make_probe ~picture) all_cells

let best_cell ~min_score score_of =
  let best =
    List.fold_left
      (fun acc (ci, ri) ->
        let s = score_of (cell_id ci ri) in
        match acc with
        | None when s >= min_score -> Some (ci, ri, s)
        | Some (_, _, bs) when s > bs -> Some (ci, ri, s)
        | _ -> acc)
      None all_cells
  in
  Option.map (fun (ci, ri, _) -> { dx = ci - 1; dy = ri - 1 }) best

let share m id = Option.value (CS.read m id) ~default:0.
let locate m = best_cell ~min_score:min_star_share (share m)

let locate_diff ~before ~after =
  best_cell ~min_score:min_diff_share (fun id ->
      share after id -. share before id)

let dir_of_offset { dx; dy } =
  if dy < 0 then Corridor_nav.North
  else if dy > 0 then Corridor_nav.South
  else if dx > 0 then Corridor_nav.East
  else Corridor_nav.West

let direction m = Option.map dir_of_offset (locate m)
