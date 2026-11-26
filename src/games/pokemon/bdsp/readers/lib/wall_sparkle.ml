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
let torch_r_min = 240
let torch_g_min = 0
let torch_b_min = 0
let torch_r_max = 255
let torch_g_max = 140
let torch_b_max = 40
let torch_min = (torch_r_min, torch_g_min, torch_b_min)
let torch_max = (torch_r_max, torch_g_max, torch_b_max)

(* Area-normalized screen-fraction thresholds (share * box.w * box.h) so the
   same sparkle star scores identically in wide side cells (East/West walls)
   and narrow center cells. Measured from run-64, run-74, and run-78/000055.jpg:
   wall torches have ~765 red-orange halo pixels (screen share ~0.0033) while
   sparkle stars have 0 red-orange halo pixels. *)
let min_star_screen_share = 0.000045
let min_diff_screen_share = 0.000025
let max_torch_screen_share = 0.0008
let cell_id ci ri = Printf.sprintf "bdsp_wall_star_%d_%d" ci ri
let torch_id ci ri = Printf.sprintf "bdsp_wall_torch_%d_%d" ci ri

let all_cells =
  List.concat_map (fun ri -> List.init 3 (fun ci -> (ci, ri))) [ 0; 1; 2 ]

let cell_box ci ri : Wire.box =
  let x, w = col_bounds_for ri ci in
  let y, h = row_bounds.(ri) in
  { x; y; w; h }

let cell_area ci ri =
  let b = cell_box ci ri in
  b.w *. b.h

let make_probes ~picture (ci, ri) =
  match PB.clipped ~picture (cell_box ci ri) with
  | None -> []
  | Some b ->
      [
        Wire.color_count_probe ~id:(cell_id ci ri) ~box:b ~min:star_min
          ~max:star_max ~delivery:Every;
        Wire.color_count_probe ~id:(torch_id ci ri) ~box:b ~min:torch_min
          ~max:torch_max ~delivery:Every;
      ]

let probes ~picture = List.concat_map (make_probes ~picture) all_cells
let share m id = Option.value (CS.read m id) ~default:0.

let has_torch m ci ri =
  share m (torch_id ci ri) *. cell_area ci ri >= max_torch_screen_share

let pick_better ~min_score ~torch_frame score_of acc (ci, ri) =
  if has_torch torch_frame ci ri then acc
  else
    let s = score_of (cell_id ci ri) *. cell_area ci ri in
    match acc with
    | None when s >= min_score -> Some (ci, ri, s)
    | Some (_, _, bs) when s > bs -> Some (ci, ri, s)
    | _ -> acc

let best_cell ~min_score ~torch_frame score_of =
  let best =
    List.fold_left (pick_better ~min_score ~torch_frame score_of) None all_cells
  in
  Option.map (fun (ci, ri, _) -> { dx = ci - 1; dy = ri - 1 }) best

let locate m =
  best_cell ~min_score:min_star_screen_share ~torch_frame:m (share m)

let locate_diff ~before ~after =
  best_cell ~min_score:min_diff_screen_share ~torch_frame:after (fun id ->
      share after id -. share before id)

let dir_of_offset { dx; dy } =
  if dy < 0 then Corridor_nav.North
  else if dy > 0 then Corridor_nav.South
  else if dx > 0 then Corridor_nav.East
  else Corridor_nav.West

let direction m = Option.map dir_of_offset (locate m)
