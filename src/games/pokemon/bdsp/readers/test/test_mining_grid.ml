open Bdsp_readers
open Bdsp_underground

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let mk_stats (r, g, b) (sr, sg, sb) : Switch_home.Solid_color.stats =
  { mean = { Wire.r; g; b }; stddev = { Wire.r = sr; g = sg; b = sb } }

let assert_cell label expected stats =
  let actual = Mining_grid.classify_cell stats in
  if actual <> expected then fail (label ^ ": unexpected classification")

let () =
  (* Measured RGB/stddev values from Console A capture run-16/000018.jpg. *)
  assert_cell "clear_empty" Mining_wall.Clear_empty
    (mk_stats (133.5, 100.6, 73.4) (2.0, 2.0, 2.9));
  assert_cell "clear_empty2" Mining_wall.Clear_empty
    (mk_stats (103.1, 78.2, 51.9) (11.7, 8.6, 8.5));
  assert_cell "iron_bar" Mining_wall.Clear_iron
    (mk_stats (99.1, 95.7, 88.7) (28.7, 28.6, 26.8));
  assert_cell "iron_bar2" Mining_wall.Clear_iron
    (mk_stats (91.3, 88.6, 79.7) (26.4, 26.0, 24.7));
  assert_cell "tan_shallow" (Mining_wall.Covered 1)
    (mk_stats (141.8, 124.9, 85.1) (10.5, 9.7, 13.6));
  assert_cell "grey_mid" (Mining_wall.Covered 2)
    (mk_stats (126.3, 125.8, 119.7) (23.2, 23.3, 23.8));
  assert_cell "boulder_deep" (Mining_wall.Covered 4)
    (mk_stats (201.4, 203.2, 196.1) (40.3, 39.8, 39.5));
  assert_cell "green_item"
    (Mining_wall.Clear_item { id = 2; kind = Mining_goal.Other })
    (mk_stats (85.0, 60.3, 32.5) (21.7, 22.7, 18.9));
  assert_cell "pink_shard"
    (Mining_wall.Clear_item { id = 1; kind = Mining_goal.Shard_s })
    (mk_stats (195.0, 90.0, 175.0) (25.0, 20.0, 25.0));
  (* Red Sphere (run-4 Dig #1) must NOT be misclassified as Shard_s. *)
  assert_cell "red_sphere_not_shard"
    (Mining_wall.Clear_item { id = 2; kind = Mining_goal.Other })
    (mk_stats (155.0, 75.0, 80.0) (30.0, 25.0, 25.0));
  (* Bright & shadowed empty floor (run-4) must classify as Clear_empty. *)
  assert_cell "bright_empty_floor" Mining_wall.Clear_empty
    (mk_stats (141.0, 112.0, 80.0) (6.0, 6.0, 7.0));
  assert_cell "shadowed_empty_floor" Mining_wall.Clear_empty
    (mk_stats (104.0, 80.0, 59.0) (23.0, 23.0, 23.0));
  (* Dusty warm rock in 18..25 rb range must stay Covered, not Clear_item. *)
  assert_cell "dusty_warm_rock" (Mining_wall.Covered 2)
    (mk_stats (170.0, 167.0, 152.0) (20.0, 20.0, 20.0));
  (* Shadowed col-0 Layer-1 tan dirt from Console A run-2/000138.jpg (0,0) & (0,9). *)
  assert_cell "shadowed_tan_dirt_top" (Mining_wall.Covered 1)
    (mk_stats (116.8, 105.4, 75.7) (14.6, 16.2, 20.8));
  assert_cell "shadowed_tan_dirt_bot" (Mining_wall.Covered 1)
    (mk_stats (110.2, 102.4, 74.4) (21.2, 19.8, 22.1));
  print_endline "OK"
