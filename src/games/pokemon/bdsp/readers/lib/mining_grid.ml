open Bdsp_underground
module PB = Switch_home.Picture_box
module SC = Switch_home.Solid_color
module CS = Switch_home.Color_share

let cols = Mining_wall.cols
let rows = Mining_wall.rows

(* Measured from Console A captures run-15/000019.jpg and run-16/000018.jpg. *)
let grid_x = 0.1328
let grid_y = 0.1111
let grid_w = 0.6156
let grid_h = 0.8444
let cell_inset = 0.20
let cell_span = 0.60

(* Top wall-crack gauge bar measured from Console A run-73/000005..000048.jpg:
   crack grows right-to-left across x=0.13..0.85, y=0.00..0.095. *)
let crack_slices = 10
let crack_x = 0.13
let crack_w = 0.72
let crack_y = 0.0
let crack_h = 0.095
let crack_ch_zero = 0
let crack_max_r = 90
let crack_max_g = 80
let crack_max_b = 65
let crack_min_rgb = (crack_ch_zero, crack_ch_zero, crack_ch_zero)
let crack_max_rgb = (crack_max_r, crack_max_g, crack_max_b)
let crack_min_share = 0.06
let crack_full_collapse_share = 0.30
let crack_half_slice = 0.5
let crack_probe_id idx = Printf.sprintf "bdsp_mine_crack_%d" idx

(* Classification thresholds measured from Console A captures. *)
let neutral_max_rb_diff = 18.
let deep_min_luma = 165.
let mid_min_luma = 115.
let tan_min_g = 115.
let tan_min_rb_diff = 30.
let tan_max_rg_diff = 25.
let empty_min_rb_diff = 35.
let empty_min_rg_diff = 20.
let empty_max_std_sum = 35.
let shard_min_r = 150.
let shard_min_b = 85.
let shard_min_rg_diff = 40.
let shard_min_bg_diff = 8.
let deep_layer = 4
let mid_layer = 2
let shallow_layer = 1
let exposed_shard_id = 1
let exposed_other_id = 2
let channels = 3.
let cell_probe_id ~col ~row = Printf.sprintf "bdsp_mine_%d_%d" col row
let red_tool_probe_id = "bdsp_mine_tool_red"
let blue_tool_probe_id = "bdsp_mine_tool_blue"
let red_tool_box : Wire.box = { x = 0.89; y = 0.42; w = 0.06; h = 0.16 }
let blue_tool_box : Wire.box = { x = 0.89; y = 0.70; w = 0.06; h = 0.16 }

let cell_box ~col ~row : Wire.box =
  let cw = grid_w /. float_of_int cols in
  let ch = grid_h /. float_of_int rows in
  {
    x = grid_x +. ((float_of_int col +. cell_inset) *. cw);
    y = grid_y +. ((float_of_int row +. cell_inset) *. ch);
    w = cell_span *. cw;
    h = cell_span *. ch;
  }

let tool_panel_probes ~picture =
  let add id box acc =
    match PB.clipped ~picture box with
    | Some b -> Wire.color_stats_probe ~id ~box:b ~delivery:Every :: acc
    | None -> acc
  in
  []
  |> add blue_tool_probe_id blue_tool_box
  |> add red_tool_probe_id red_tool_box

let crack_slice_box idx : Wire.box =
  let sw = crack_w /. float_of_int crack_slices in
  { x = crack_x +. (float_of_int idx *. sw); y = crack_y; w = sw; h = crack_h }

let crack_slice_probe ~picture idx =
  let make box =
    Wire.color_count_probe ~id:(crack_probe_id idx) ~box ~min:crack_min_rgb
      ~max:crack_max_rgb ~delivery:Every
  in
  Option.map make (PB.clipped ~picture (crack_slice_box idx))

let crack_gauge_probes ~picture =
  List.init crack_slices (crack_slice_probe ~picture) |> List.filter_map Fun.id

let probes ~picture =
  let acc = ref [] in
  for r = 0 to rows - 1 do
    for c = 0 to cols - 1 do
      let id = cell_probe_id ~col:c ~row:r in
      match PB.clipped ~picture (cell_box ~col:c ~row:r) with
      | Some box ->
          acc := Wire.color_stats_probe ~id ~box ~delivery:Every :: !acc
      | None -> ()
    done
  done;
  tool_panel_probes ~picture @ crack_gauge_probes ~picture @ List.rev !acc

let integrity_for_slice idx share =
  if idx = 0 && share >= crack_full_collapse_share then 0
  else
    let frac =
      (float_of_int idx +. crack_half_slice) /. float_of_int crack_slices
    in
    let est =
      int_of_float
        (Float.round (float_of_int Mining_wall.max_integrity *. frac))
    in
    max 0 (min Mining_wall.max_integrity est)

let rec find_leftmost_crack idx = function
  | [] -> Mining_wall.max_integrity
  | Some v :: _ when v >= crack_min_share -> integrity_for_slice idx v
  | _ :: rest -> find_leftmost_crack (idx + 1) rest

let crack_gauge_integrity m =
  let shares = List.init crack_slices (fun i -> CS.read m (crack_probe_id i)) in
  if List.for_all Option.is_none shares then None
  else Some (find_leftmost_crack 0 shares)

let min_red_panel_r = 70.
let min_blue_panel_b = 70.
let min_red_dominance = 40.
let min_blue_over_red = 10.
let stats_luma (s : SC.stats) = (s.mean.r +. s.mean.g +. s.mean.b) /. channels

let on_mining_screen m =
  match (SC.stats m red_tool_probe_id, SC.stats m blue_tool_probe_id) with
  | Some red, Some blue ->
      red.mean.r >= min_red_panel_r
      && red.mean.r -. red.mean.b >= min_red_dominance
      && blue.mean.b >= min_blue_panel_b
      && blue.mean.b -. blue.mean.r >= min_blue_over_red
  | _ -> false

let selected_tool m =
  match (SC.stats m red_tool_probe_id, SC.stats m blue_tool_probe_id) with
  | Some red, Some blue ->
      if stats_luma red > stats_luma blue then Some Mining_wall.Hammer
      else Some Mining_wall.Pickaxe
  | _ -> None

let is_pink_shard (r, g, b) =
  r >= shard_min_r && b >= shard_min_b
  && r -. g >= shard_min_rg_diff
  && b -. g >= shard_min_bg_diff

let classify_neutral luma =
  if luma >= deep_min_luma then Mining_wall.Covered deep_layer
  else if luma >= mid_min_luma then Mining_wall.Covered mid_layer
  else Mining_wall.Clear_iron

let classify_colored (r, g, b) std_sum =
  let rb = r -. b and rg = r -. g in
  if is_pink_shard (r, g, b) then
    Mining_wall.Clear_item { id = exposed_shard_id; kind = Mining_goal.Shard_s }
  else if g >= tan_min_g && rb >= tan_min_rb_diff && rg < tan_max_rg_diff then
    Mining_wall.Covered shallow_layer
  else if
    rb >= empty_min_rb_diff && rg >= empty_min_rg_diff
    && std_sum < empty_max_std_sum
  then Mining_wall.Clear_empty
  else
    Mining_wall.Clear_item { id = exposed_other_id; kind = Mining_goal.Other }

let classify_cell (s : SC.stats) =
  let r = s.mean.r and g = s.mean.g and b = s.mean.b in
  let luma = (r +. g +. b) /. channels in
  if Float.abs (r -. b) < neutral_max_rb_diff then classify_neutral luma
  else classify_colored (r, g, b) (SC.sum s.stddev)

let read_cell m ~col ~row =
  match SC.stats m (cell_probe_id ~col ~row) with
  | Some s -> classify_cell s
  | None -> Mining_wall.Covered mid_layer

let cursor_occludes ~cursor ~col ~row =
  match cursor with
  | None -> false
  | Some (cc, cr) -> col >= cc && col <= cc + 1 && row >= cr - 1 && row <= cr

let read_cell_masked ~cursor ~prev m ~col ~row =
  if not (cursor_occludes ~cursor ~col ~row) then read_cell m ~col ~row
  else
    match prev with
    | Some g -> g.(row).(col)
    | None -> Mining_wall.Covered mid_layer

let read_observation ?cursor ?prev ~announced_items ~integrity m =
  let grid =
    Array.init rows (fun row ->
        Array.init cols (fun col -> read_cell_masked ~cursor ~prev m ~col ~row))
  in
  {
    Mining_wall.cols;
    rows;
    integrity;
    collapsed = integrity <= 0;
    announced_items;
    grid;
    uncovered_ids = [];
  }
