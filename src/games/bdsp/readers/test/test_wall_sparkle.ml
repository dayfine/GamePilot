open Bdsp_readers
module WS = Wall_sparkle

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_true label cond = if not cond then fail label
let full_pic : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }

let frame_of pairs : Wire.frame =
  let probes =
    List.map
      (fun (id, fraction) -> (id, Wire.Color_count { fraction; mean = None }))
      pairs
  in
  { seq = 1; t_ms = 0.; probes }

let cell ci ri = Printf.sprintf "bdsp_wall_star_%d_%d" ci ri

let test_probe_layout () =
  let ps = WS.probes ~picture:full_pic in
  assert_true "9 probes for 3x3 grid" (List.length ps = 9);
  let find id = List.find (fun (p : Wire.probe_spec) -> p.id = id) ps in
  let top_left = find (cell 0 0) in
  let mid_left = find (cell 0 1) in
  let mid_right = find (cell 2 1) in
  assert_true "top-left cell excludes minimap (x >= 0.25)"
    (top_left.box.x >= 0.25);
  assert_true "mid-left cell extends to West wall (x <= 0.15)"
    (mid_left.box.x <= 0.15);
  assert_true "mid-right cell extends to East wall (x + w >= 0.87)"
    (mid_right.box.x +. mid_right.box.w >= 0.87)

let test_torch_cancellation_and_east_wall () =
  (* Static orange torch in (1, 0) stays constant; new oblique East-wall star
     appears in (2, 1) with share 0.0008 (run-64 R#11). *)
  let before = frame_of [ (cell 1 0, 0.0020); (cell 2 1, 0.0000) ] in
  let after = frame_of [ (cell 1 0, 0.0020); (cell 2 1, 0.0008) ] in
  assert_true "locate_diff cancels torch and finds East wall star"
    (WS.locate_diff ~before ~after = Some { WS.dx = 1; dy = 0 })

let test_north_wall_star () =
  let before = frame_of [ (cell 1 0, 0.0006) ] in
  let after = frame_of [ (cell 1 0, 0.0035) ] in
  assert_true "North wall star detected above player"
    (WS.locate_diff ~before ~after = Some { WS.dx = 0; dy = -1 })

let test_west_wall_star () =
  let before = frame_of [ (cell 0 1, 0.0001); (cell 2 1, 0.0018) ] in
  let after = frame_of [ (cell 0 1, 0.0007); (cell 2 1, 0.0018) ] in
  assert_true "West wall star detected left of player"
    (WS.locate_diff ~before ~after = Some { WS.dx = -1; dy = 0 })

let test_noise_below_threshold () =
  let before = frame_of [ (cell 1 0, 0.0005) ] in
  let after = frame_of [ (cell 1 0, 0.0006) ] in
  assert_true "small jitter below diff threshold returns None"
    (WS.locate_diff ~before ~after = None)

let test_locate_oblique_east_star () =
  (* Oblique East-wall star in (1, 1) after stepping (run-64 000247.jpg). *)
  let m = frame_of [ (cell 1 1, 0.0015) ] in
  assert_true "locate detects oblique East-wall star"
    (WS.locate m = Some { WS.dx = 0; dy = 0 })

let () =
  test_probe_layout ();
  test_torch_cancellation_and_east_wall ();
  test_north_wall_star ();
  test_west_wall_star ();
  test_noise_below_threshold ();
  test_locate_oblique_east_star ();
  print_endline "OK"
