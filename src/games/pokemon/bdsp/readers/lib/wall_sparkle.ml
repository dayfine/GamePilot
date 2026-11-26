open Bdsp_underground
module PB = Switch_home.Picture_box
module CS = Switch_home.Color_share

type offset = { dx : int; dy : int }

(* 3x3 screen grid around the player (x=0.50, y=0.48), excluding the top-left
   minimap (x<0.24, y<0.36). Row 0 starts at y=0.06 so North-wall stars stay
   inside row 0; col 0 extends left to x=0.14 in rows 1-2 (below the minimap)
   so oblique West-wall stars are covered, and col 2 extends to x=0.88 so
   East-wall stars are covered even when hugging the West wall. *)
let col_left_top_x = 0.25
let col_left_top_w = 0.17
let col_left_x = 0.14
let col_left_w = 0.28
let col_mid_x = 0.42
let col_mid_w = 0.16
let col_right_x = 0.58
let col_right_w = 0.30
let row_top_y = 0.06
let row_top_h = 0.30
let row_mid_y = 0.36
let row_mid_h = 0.22
let row_bot_y = 0.58
let row_bot_h = 0.28

let row_bounds =
  [| (row_top_y, row_top_h); (row_mid_y, row_mid_h); (row_bot_y, row_bot_h) |]

let col_bounds_for ri ci =
  match ci with
  | 0 ->
      if ri = 0 then (col_left_top_x, col_left_top_w)
      else (col_left_x, col_left_w)
  | 1 -> (col_mid_x, col_mid_w)
  | _ -> (col_right_x, col_right_w)

let star_r_min = 240
let star_g_min = 245
let star_b_min = 235
let star_r_max = 255
let star_g_max = 255
let star_b_max = 255
let star_min = (star_r_min, star_g_min, star_b_min)
let star_max = (star_r_max, star_g_max, star_b_max)

(* Area-normalized screen-fraction thresholds (share * box.w * box.h) so the
   same sparkle star scores identically in wide side cells (East/West walls)
   and narrow center cells. Measured from run-64 and run-74 30fps wire logs:
   oblique East-wall stars reach 4.6e-5..3.7e-4; noise floor is <= 5e-6. *)
let min_star_screen_share = 0.000045
let min_diff_screen_share = 0.000025
let cell_id ci ri = Printf.sprintf "bdsp_wall_star_%d_%d" ci ri

let all_cells =
  List.concat_map (fun ri -> List.init 3 (fun ci -> (ci, ri))) [ 0; 1; 2 ]

let cell_box ci ri : Wire.box =
  let x, w = col_bounds_for ri ci in
  let y, h = row_bounds.(ri) in
  { x; y; w; h }

let cell_area ci ri =
  let b = cell_box ci ri in
  b.w *. b.h

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
        let s = score_of (cell_id ci ri) *. cell_area ci ri in
        match acc with
        | None when s >= min_score -> Some (ci, ri, s)
        | Some (_, _, bs) when s > bs -> Some (ci, ri, s)
        | _ -> acc)
      None all_cells
  in
  Option.map (fun (ci, ri, _) -> { dx = ci - 1; dy = ri - 1 }) best

let share m id = Option.value (CS.read m id) ~default:0.
let locate m = best_cell ~min_score:min_star_screen_share (share m)

let locate_diff ~before ~after =
  best_cell ~min_score:min_diff_screen_share (fun id ->
      share after id -. share before id)

let dir_of_offset { dx; dy } =
  if dy < 0 then Corridor_nav.North
  else if dy > 0 then Corridor_nav.South
  else if dx > 0 then Corridor_nav.East
  else Corridor_nav.West

let direction m = Option.map dir_of_offset (locate m)
