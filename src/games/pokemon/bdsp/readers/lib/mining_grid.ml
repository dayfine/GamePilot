open Bdsp_underground
module PB = Switch_home.Picture_box
module SC = Switch_home.Solid_color
module CS = Switch_home.Color_share

type crack_config = {
  slices : int;
  box : Wire.box;
  max_r : int;
  max_g : int;
  max_b : int;
  min_share : float;
  full_collapse_share : float;
}

type cell_rules = {
  neutral_max_rb : float;
  neutral_max_rg : float;
  deep_min_luma : float;
  mid_min_luma : float;
  tan_min_g : float;
  tan_min_rb : float;
  tan_max_rg : float;
  empty_min_r : float;
  empty_max_r : float;
  empty_max_g : float;
  empty_max_b : float;
  empty_min_rg : float;
  empty_min_gb : float;
  empty_max_std : float;
  shard_min_r : float;
  shard_min_b : float;
  shard_min_rg : float;
  shard_min_bg : float;
}

type tool_panel_rule = {
  red_box : Wire.box;
  blue_box : Wire.box;
  min_red_r : float;
  min_blue_b : float;
  min_red_dom : float;
  min_blue_over_red : float;
}

let cols = Mining_wall.cols
let rows = Mining_wall.rows

(* Measured from Console A captures run-15/000019.jpg and run-16/000018.jpg. *)
let grid_box : Wire.box = { x = 0.1328; y = 0.1111; w = 0.6156; h = 0.8444 }
let cell_inset = 0.20
let cell_span = 0.60

(* Top wall-crack gauge bar measured from Console A run-73/000005..000048.jpg:
   crack grows right-to-left across x=0.13..0.85, y=0.00..0.095. *)
let crack =
  {
    slices = 10;
    box = { x = 0.13; y = 0.0; w = 0.72; h = 0.095 };
    max_r = 90;
    max_g = 80;
    max_b = 65;
    min_share = 0.10;
    full_collapse_share = 0.30;
  }

(* Classification thresholds measured from Console A captures. *)
let rules =
  {
    neutral_max_rb = 25.;
    neutral_max_rg = 18.;
    deep_min_luma = 165.;
    mid_min_luma = 115.;
    tan_min_g = 95.;
    tan_min_rb = 25.;
    tan_max_rg = 25.;
    empty_min_r = 92.;
    empty_max_r = 148.;
    empty_max_g = 118.;
    empty_max_b = 90.;
    empty_min_rg = 22.;
    empty_min_gb = 18.;
    empty_max_std = 80.;
    shard_min_r = 122.;
    shard_min_b = 70.;
    shard_min_rg = 42.;
    shard_min_bg = 12.;
  }

let tool_panel =
  {
    red_box = { x = 0.89; y = 0.42; w = 0.06; h = 0.16 };
    blue_box = { x = 0.89; y = 0.70; w = 0.06; h = 0.16 };
    min_red_r = 70.;
    min_blue_b = 70.;
    min_red_dom = 40.;
    min_blue_over_red = 10.;
  }

let deep_layer = 4
let mid_layer = 2
let shallow_layer = 1
let exposed_shard_id = 1
let exposed_other_id = 2
let channels = 3.
let crack_probe_id idx = Printf.sprintf "bdsp_mine_crack_%d" idx
let cell_probe_id ~col ~row = Printf.sprintf "bdsp_mine_%d_%d" col row
let red_tool_probe_id = "bdsp_mine_tool_red"
let blue_tool_probe_id = "bdsp_mine_tool_blue"

let cell_box ~col ~row : Wire.box =
  let cw = grid_box.w /. float_of_int cols in
  let ch = grid_box.h /. float_of_int rows in
  {
    x = grid_box.x +. ((float_of_int col +. cell_inset) *. cw);
    y = grid_box.y +. ((float_of_int row +. cell_inset) *. ch);
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
  |> add blue_tool_probe_id tool_panel.blue_box
  |> add red_tool_probe_id tool_panel.red_box

let crack_slice_box idx : Wire.box =
  let sw = crack.box.w /. float_of_int crack.slices in
  {
    x = crack.box.x +. (float_of_int idx *. sw);
    y = crack.box.y;
    w = sw;
    h = crack.box.h;
  }

let crack_slice_probe ~picture idx =
  let make box =
    Wire.color_count_probe ~id:(crack_probe_id idx) ~box ~min:(0, 0, 0)
      ~max:(crack.max_r, crack.max_g, crack.max_b)
      ~delivery:Every
  in
  Option.map make (PB.clipped ~picture (crack_slice_box idx))

let crack_gauge_probes ~picture =
  List.init crack.slices (crack_slice_probe ~picture) |> List.filter_map Fun.id

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
  if idx = 0 && share >= crack.full_collapse_share then 0
  else
    let frac = (float_of_int idx +. 0.5) /. float_of_int crack.slices in
    let est =
      int_of_float
        (Float.round (float_of_int Mining_wall.max_integrity *. frac))
    in
    max 0 (min Mining_wall.max_integrity est)

let rec find_leftmost_crack idx = function
  | [] -> Mining_wall.max_integrity
  | Some v :: _ when v >= crack.min_share -> integrity_for_slice idx v
  | _ :: rest -> find_leftmost_crack (idx + 1) rest

let crack_gauge_integrity m =
  let shares = List.init crack.slices (fun i -> CS.read m (crack_probe_id i)) in
  if List.for_all Option.is_none shares then None
  else Some (find_leftmost_crack 0 shares)

let stats_luma (s : SC.stats) = (s.mean.r +. s.mean.g +. s.mean.b) /. channels

let on_mining_screen m =
  match (SC.stats m red_tool_probe_id, SC.stats m blue_tool_probe_id) with
  | Some red, Some blue ->
      red.mean.r >= tool_panel.min_red_r
      && red.mean.r -. red.mean.b >= tool_panel.min_red_dom
      && blue.mean.b >= tool_panel.min_blue_b
      && blue.mean.b -. blue.mean.r >= tool_panel.min_blue_over_red
  | _ -> false

let selected_tool m =
  match (SC.stats m red_tool_probe_id, SC.stats m blue_tool_probe_id) with
  | Some red, Some blue ->
      if stats_luma red > stats_luma blue then Some Mining_wall.Hammer
      else Some Mining_wall.Pickaxe
  | _ -> None

let is_pink_shard (r, g, b) =
  r >= rules.shard_min_r && b >= rules.shard_min_b
  && r -. g >= rules.shard_min_rg
  && b -. g >= rules.shard_min_bg

let classify_neutral luma =
  if luma >= rules.deep_min_luma then Mining_wall.Covered deep_layer
  else if luma >= rules.mid_min_luma then Mining_wall.Covered mid_layer
  else Mining_wall.Clear_iron

let is_empty_floor (r, g, b) std_sum =
  r >= rules.empty_min_r && r <= rules.empty_max_r && g <= rules.empty_max_g
  && b <= rules.empty_max_b
  && r -. g >= rules.empty_min_rg
  && g -. b >= rules.empty_min_gb
  && std_sum < rules.empty_max_std

let classify_colored (r, g, b) std_sum =
  let rb = r -. b and rg = r -. g in
  if is_pink_shard (r, g, b) then
    Mining_wall.Clear_item { id = exposed_shard_id; kind = Mining_goal.Shard_s }
  else if
    g >= rules.tan_min_g && rb >= rules.tan_min_rb && rg < rules.tan_max_rg
  then Mining_wall.Covered shallow_layer
  else if is_empty_floor (r, g, b) std_sum then Mining_wall.Clear_empty
  else
    Mining_wall.Clear_item { id = exposed_other_id; kind = Mining_goal.Other }

let classify_cell (s : SC.stats) =
  let r = s.mean.r and g = s.mean.g and b = s.mean.b in
  let luma = (r +. g +. b) /. channels in
  if
    Float.abs (r -. b) < rules.neutral_max_rb
    && Float.abs (r -. g) < rules.neutral_max_rg
  then classify_neutral luma
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
  let uncovered_ids = Mining_components.label_and_infer_uncovered grid in
  {
    Mining_wall.cols;
    rows;
    integrity;
    collapsed = integrity <= 0;
    announced_items;
    grid;
    uncovered_ids;
  }
