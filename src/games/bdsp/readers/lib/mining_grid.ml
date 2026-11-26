open Bdsp_underground
module PB = Switch_home.Picture_box
module SC = Switch_home.Solid_color

let cols = Mining_wall.cols
let rows = Mining_wall.rows

(* Measured from Console A captures run-15/000019.jpg and run-16/000018.jpg. *)
let grid_x = 0.1328
let grid_y = 0.1111
let grid_w = 0.6156
let grid_h = 0.8444
let cell_inset = 0.20
let cell_span = 0.60

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
let shard_min_b = 130.
let shard_min_rg_diff = 40.
let shard_min_bg_diff = 20.
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

let tool_probes ~picture =
  let add id box acc =
    match PB.clipped ~picture box with
    | Some b -> Wire.color_stats_probe ~id ~box:b ~delivery:Every :: acc
    | None -> acc
  in
  []
  |> add blue_tool_probe_id blue_tool_box
  |> add red_tool_probe_id red_tool_box

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
  tool_probes ~picture @ List.rev !acc

let stats_luma (s : SC.stats) = (s.mean.r +. s.mean.g +. s.mean.b) /. channels

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
