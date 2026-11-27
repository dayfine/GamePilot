open Bdsp_underground
module RN = Bdsp_underground_program.Ring_navigator
module WS = Bdsp_readers.Wall_sparkle
module D = Grid_geometry.Direction

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_true label cond = if not cond then fail label

let test_se_corner_faces_east_and_steps_north () =
  (* Exact 2026-11-26-run-1/000128.jpg case: arrived East at SE corner (14, 20)
     where wall_dirs = [East] (North is open east_vertical corridor), radar
     detected star at dx=+1, dy=-1. Must face East and step North along the
     East wall (never East into the wall!). *)
  let wall_dirs = Ring_grid.adjacent_walls { x = 14; y = 20 } in
  assert_true "SE corner (14, 20) only has East wall" (wall_dirs = [ D.East ]);
  let fallback = RN.primary_wall_dir ~along_dir:D.East wall_dirs in
  assert_true "SE corner fallback faces East" (fallback = D.East);
  let off = { WS.dx = 1; dy = -1; dx_norm = 0.05; dy_norm = -0.15 } in
  let face = RN.wall_from_offset ~along_dir:D.East ~wall_dirs ~fallback off in
  assert_true "SE corner star at dx=1 dy=-1 faces East" (face = D.East);
  let step = RN.servo_step_toward ~face_dir:face off in
  assert_true "SE corner servo steps North along East wall" (step = Some D.North)

let test_bottom_east_faces_north_and_steps_east () =
  (* Exact run-2/000268.jpg case: mid bottom_east (10, 20), wall_dirs=[North],
     star slightly right -> dx=+1, dy=0 -> faces North, steps East. *)
  let wall_dirs = Ring_grid.adjacent_walls { x = 10; y = 20 } in
  assert_true "bottom_east (10, 20) only has North wall"
    (wall_dirs = [ D.North ]);
  let fallback = RN.primary_wall_dir ~along_dir:D.East wall_dirs in
  assert_true "bottom_east fallback faces North" (fallback = D.North);
  let off = { WS.dx = 1; dy = 0; dx_norm = 0.06; dy_norm = -0.02 } in
  let face = RN.wall_from_offset ~along_dir:D.East ~wall_dirs ~fallback off in
  assert_true "bottom_east star faces North" (face = D.North);
  let step = RN.servo_step_toward ~face_dir:face off in
  assert_true "bottom_east servo steps East along North wall"
    (step = Some D.East)

let test_east_vertical_never_faces_south () =
  let wall_dirs = [ D.East; D.South ] in
  let fallback = RN.primary_wall_dir ~along_dir:D.North wall_dirs in
  assert_true "east_vertical ignores South rim and faces East"
    (fallback = D.East);
  let aligned =
    RN.servo_step_toward ~face_dir:fallback
      { WS.dx = 1; dy = 0; dx_norm = 0.05; dy_norm = 0.0 }
  in
  assert_true "dy=0 along East wall is already aligned" (aligned = None)

let test_servo_hold_uses_screen_tiles () =
  (* run-5/000061.jpg: star 2 tiles North (dy_norm=-0.26) -> ~450ms, not 1540ms. *)
  let off = { WS.dx = 1; dy = -1; dx_norm = 0.05; dy_norm = -0.26 } in
  let ms =
    Bdsp_underground_program.Wall_lock.servo_hold_ms ~face_dir:D.East off
  in
  assert_true "2 screen tiles North is 350..600ms" (ms >= 350 && ms <= 600)

let () =
  test_se_corner_faces_east_and_steps_north ();
  test_bottom_east_faces_north_and_steps_east ();
  test_east_vertical_never_faces_south ();
  test_servo_hold_uses_screen_tiles ();
  print_endline "OK"
