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
  (* Half-exposed Shard S measured from Console A run-78/000271.jpg cell (9,5). *)
  assert_cell "half_exposed_shard_s"
    (Mining_wall.Clear_item { id = 1; kind = Mining_goal.Shard_s })
    (mk_stats (128.5, 80.3, 76.7) (40.0, 30.0, 30.0));
  print_endline "OK"
