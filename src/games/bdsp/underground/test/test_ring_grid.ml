open Bdsp_underground
module D = Grid_geometry.Direction
module P = Grid_geometry.Tile_pos

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_true label cond = if not cond then fail label

let test_route_bottom_east_returns_south () =
  let wp = Ring_grid.waypoint_of_bucket ~segment:Bottom_east ~bucket:1 in
  let r = Ring_grid.plan_route ~start:Ring_grid.south_door ~waypoints:[ wp ] in
  assert_true "one stop" (List.length r.stops = 1);
  assert_true "returns to south door"
    (P.equal r.return_door Ring_grid.south_door);
  assert_true "non-empty legs to stop" ((List.hd r.stops).legs <> []);
  assert_true "non-empty return legs" (r.return_legs <> [])

let test_route_top_east_exits_north_door () =
  let wp1 = Ring_grid.waypoint_of_bucket ~segment:East_vertical ~bucket:2 in
  let wp2 = Ring_grid.waypoint_of_bucket ~segment:Top_east ~bucket:2 in
  let r =
    Ring_grid.plan_route ~start:Ring_grid.south_door ~waypoints:[ wp1; wp2 ]
  in
  assert_true "two stops" (List.length r.stops = 2);
  assert_true "exits via closer north door"
    (P.equal r.return_door Ring_grid.north_door)

let test_corner_adjacent_walls () =
  let se_corner : P.t = { x = 14; y = 22 } in
  let walls = Ring_grid.adjacent_walls se_corner in
  assert_true "SE corner has South wall" (List.mem D.South walls);
  assert_true "SE corner has East wall" (List.mem D.East walls)

let () =
  test_route_bottom_east_returns_south ();
  test_route_top_east_exits_north_door ();
  test_corner_adjacent_walls ();
  print_endline "OK"
