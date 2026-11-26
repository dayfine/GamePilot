open Bdsp_underground
module D = Grid_geometry.Direction
module L = Grid_planning.Leg
module P = Grid_geometry.Tile_pos

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_true label cond = if not cond then fail label

let is_to_wall_leg (leg : _ L.t) =
  match leg.kind with L.Walk { to_wall; _ } -> to_wall | _ -> false

let test_route_bottom_east_returns_south () =
  let wp = Ring_grid.waypoint_of_bucket ~segment:Bottom_east ~bucket:2 in
  let r = Ring_grid.plan_route ~start:Ring_grid.south_door ~waypoints:[ wp ] in
  assert_true "one stop" (List.length r.stops = 1);
  assert_true "bottom_east runs on North-wall track y=20" (wp.y = 20);
  assert_true "returns to south door"
    (P.equal r.return_door Ring_grid.south_door);
  assert_true "non-empty legs to stop" ((List.hd r.stops).legs <> []);
  assert_true "return leg wall-brakes into south door"
    (List.exists is_to_wall_leg r.return_legs)

let test_route_top_east_exits_north_door () =
  let wp1 = Ring_grid.waypoint_of_bucket ~segment:East_vertical ~bucket:5 in
  let wp2 = Ring_grid.waypoint_of_bucket ~segment:Top_east ~bucket:5 in
  let r =
    Ring_grid.plan_route ~start:Ring_grid.south_door ~waypoints:[ wp1; wp2 ]
  in
  assert_true "two stops" (List.length r.stops = 2);
  assert_true "east_vertical on x=14" (wp1.x = 14);
  assert_true "top_east on y=1" (wp2.y = 1);
  assert_true "exits via closer north door"
    (P.equal r.return_door Ring_grid.north_door);
  assert_true "return leg wall-brakes into north door"
    (List.exists is_to_wall_leg r.return_legs)

let test_corner_wall_braking () =
  let se_wp = Ring_grid.waypoint_of_bucket ~segment:Bottom_east ~bucket:7 in
  let ne_wp = Ring_grid.waypoint_of_bucket ~segment:Top_east ~bucket:0 in
  let r =
    Ring_grid.plan_route ~start:Ring_grid.south_door ~waypoints:[ se_wp; ne_wp ]
  in
  assert_true "two corner stops" (List.length r.stops = 2);
  let st_se = List.nth r.stops 0 in
  let st_ne = List.nth r.stops 1 in
  assert_true "SE corner waypoint is (14, 20)"
    (P.equal st_se.tile { x = 14; y = 20 });
  assert_true "SE corner leg wall-brakes (to_wall=true)"
    (List.exists is_to_wall_leg st_se.legs);
  assert_true "SE corner has East wall" (List.mem D.East st_se.wall_dirs);
  assert_true "NE corner waypoint is (14, 1)"
    (P.equal st_ne.tile { x = 14; y = 1 });
  assert_true "NE corner leg wall-brakes (to_wall=true)"
    (List.exists is_to_wall_leg st_ne.legs);
  assert_true "NE corner has North and East walls"
    (List.mem D.North st_ne.wall_dirs && List.mem D.East st_ne.wall_dirs)

let test_all_8_buckets_valid () =
  let check seg expected_coord =
    for b = 0 to 7 do
      let wp = Ring_grid.waypoint_of_bucket ~segment:seg ~bucket:b in
      assert_true "waypoint reachable from south door"
        (Option.is_some
           (Ring_grid.plan_legs ~start:Ring_grid.south_door ~goal:wp));
      assert_true "waypoint on expected track" (expected_coord wp)
    done
  in
  check Ring_grid.Bottom_east (fun p -> p.y = 20);
  check Ring_grid.East_vertical (fun p -> p.x = 14);
  check Ring_grid.Top_east (fun p -> p.y = 1)

let test_corner_adjacent_walls () =
  let se_corner : P.t = { x = 14; y = 22 } in
  let walls = Ring_grid.adjacent_walls se_corner in
  assert_true "SE corner has South wall" (List.mem D.South walls);
  assert_true "SE corner has East wall" (List.mem D.East walls);
  let bot_mid : P.t = { x = 7; y = 20 } in
  let mid_walls = Ring_grid.adjacent_walls bot_mid in
  assert_true "bottom_east track faces North wall only" (mid_walls = [ D.North ])

let () =
  test_route_bottom_east_returns_south ();
  test_route_top_east_exits_north_door ();
  test_corner_wall_braking ();
  test_all_8_buckets_valid ();
  test_corner_adjacent_walls ();
  print_endline "OK"
