open Bdsp_underground

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq_int label expected actual =
  if expected <> actual then
    fail (Printf.sprintf "%s: expected %d, got %d" label expected actual)

let assert_true label cond = if not cond then fail label

let test_goal_arithmetic () =
  let goal = Mining_goal.ramanas_all_slates in
  assert_eq_int "empty remaining" 14
    (Mining_goal.remaining_slates goal Mining_goal.empty_tally);
  let t =
    Mining_goal.record_dig Mining_goal.empty_tally ~bailed:false
      [ Shard_l; Shard_s; Shard_s; Shard_s ]
  in
  assert_eq_int "slate equivalents (1L + 3S = 2)" 2
    (Mining_goal.slate_equivalents t);
  assert_eq_int "remaining after 2" 12 (Mining_goal.remaining_slates goal t);
  assert_true "not met yet" (not (Mining_goal.is_met goal t));
  let small_goal = Mining_goal.Slates 2 in
  assert_true "met for 2 slates" (Mining_goal.is_met small_goal t)

let test_wall_mechanics () =
  let dirt =
    Array.init Mining_wall.rows (fun _ -> Array.make Mining_wall.cols 2)
  in
  let shard =
    {
      Mining_wall.id = 0;
      kind = Mining_goal.Shard_s;
      cells = [ (2, 2); (3, 2); (2, 3); (3, 3) ];
    }
  in
  match Mining_wall.make ~dirt ~iron:[ (0, 0) ] ~items:[ shard ] with
  | Error e -> fail ("wall make failed: " ^ e)
  | Ok w ->
      assert_eq_int "initial integrity" 49 (Mining_wall.integrity w);
      let w1 = Mining_wall.strike w ~tool:Hammer ~col:2 ~row:2 in
      assert_eq_int "after hammer" 47 (Mining_wall.integrity w1);
      let w2 = Mining_wall.strike w1 ~tool:Pickaxe ~col:3 ~row:3 in
      assert_eq_int "after pickaxe" 46 (Mining_wall.integrity w2);
      assert_eq_int "shard uncovered" 1
        (List.length (Mining_wall.uncovered_items w2))

let mk_obs ?(integrity = Mining_wall.max_integrity) ?(announced_items = 3) grid
    =
  {
    Mining_wall.cols = Mining_wall.cols;
    rows = Mining_wall.rows;
    integrity;
    collapsed = integrity <= 0;
    announced_items;
    grid;
    uncovered_ids = [];
  }

let test_smart_tool_selection () =
  let goal = Mining_goal.ramanas_all_slates in
  let tally = Mining_goal.empty_tally in
  (* 1. Deep multi-target shard excavation with healthy gauge -> Hammer. *)
  let deep_grid =
    Array.init Mining_wall.rows (fun _ ->
        Array.make Mining_wall.cols (Mining_wall.Covered 2))
  in
  deep_grid.(5).(5) <-
    Mining_wall.Clear_item { id = 1; kind = Mining_goal.Shard_l };
  (match Mining_solver.decide ~goal ~tally (mk_obs ~integrity:30 deep_grid) with
  | Mining_solver.Strike { tool = Mining_wall.Hammer; _ } -> ()
  | _ -> fail "expected Hammer on deep multi-target shard excavation");
  (* 2. 1-layer cleanup -> Pickaxe. *)
  let shallow_grid =
    Array.init Mining_wall.rows (fun _ ->
        Array.make Mining_wall.cols (Mining_wall.Covered 1))
  in
  shallow_grid.(5).(5) <-
    Mining_wall.Clear_item { id = 1; kind = Mining_goal.Shard_l };
  (match
     Mining_solver.decide ~goal ~tally (mk_obs ~integrity:30 shallow_grid)
   with
  | Mining_solver.Strike { tool = Mining_wall.Pickaxe; _ } -> ()
  | _ -> fail "expected Pickaxe on 1-layer shard cleanup");
  (* 3. Tight gauge (< 4 integrity) -> Pickaxe even on deep multi-target. *)
  match Mining_solver.decide ~goal ~tally (mk_obs ~integrity:3 deep_grid) with
  | Mining_solver.Strike { tool = Mining_wall.Pickaxe; _ } -> ()
  | _ -> fail "expected Pickaxe when remaining integrity < 4"

let test_low_gauge_switch () =
  let goal = Mining_goal.ramanas_all_slates in
  let tally = Mining_goal.empty_tally in
  let grid =
    Array.init Mining_wall.rows (fun _ ->
        Array.make Mining_wall.cols (Mining_wall.Covered 2))
  in
  (* Exposed non-shard item at (0, 0) with only (1, 0) covered beside it. *)
  grid.(0).(0) <- Mining_wall.Clear_item { id = 2; kind = Mining_goal.Other };
  grid.(1).(0) <- Mining_wall.Clear_empty;
  grid.(0).(1) <- Mining_wall.Covered 1;
  (* High gauge: keep scanning anchors away from (0, 1). *)
  (match Mining_solver.decide ~goal ~tally (mk_obs ~integrity:30 grid) with
  | Mining_solver.Strike { tool = Mining_wall.Hammer; col; row }
    when col <> 1 || row <> 0 ->
      ()
  | _ -> fail "expected anchor scan at high gauge");
  (* Low gauge (<= 18): stop scanning and excavate (1, 0) immediately. *)
  match Mining_solver.decide ~goal ~tally (mk_obs ~integrity:16 grid) with
  | Mining_solver.Strike { tool = Mining_wall.Pickaxe; col = 1; row = 0 } -> ()
  | _ -> fail "expected immediate secondary excavation at low gauge"

let test_benchmark_200_walls () =
  let goal = Mining_goal.ramanas_all_slates in
  let tally = Mining_goal.empty_tally in
  let n = 200 in
  let shard_l_ok = ref 0 in
  for seed = 1 to n do
    let w =
      Mining_wall.generate ~seed
        ~items:[ Mining_goal.Shard_l; Mining_goal.Other; Mining_goal.Other ]
    in
    let res = Mining_solver.play_wall ~goal ~tally w in
    if List.mem Mining_goal.Shard_l res.uncovered then incr shard_l_ok
  done;
  assert_true
    (Printf.sprintf "expected >= 184/200 (92%%) Shard L recovery, got %d/%d"
       !shard_l_ok n)
    (!shard_l_ok >= 184);
  let shard_s_ok = ref 0 in
  for seed = 501 to 500 + n do
    let w =
      Mining_wall.generate ~seed
        ~items:[ Mining_goal.Shard_s; Mining_goal.Other; Mining_goal.Other ]
    in
    let res = Mining_solver.play_wall ~goal ~tally w in
    if List.mem Mining_goal.Shard_s res.uncovered then incr shard_s_ok
  done;
  assert_true
    (Printf.sprintf "expected >= 175/200 (87.5%%) Shard S recovery, got %d/%d"
       !shard_s_ok n)
    (!shard_s_ok >= 175);
  let other_ok = ref 0 in
  let finished_count = ref 0 in
  for seed = 1001 to 1000 + n do
    let w =
      Mining_wall.generate ~seed ~items:[ Mining_goal.Other; Mining_goal.Other ]
    in
    let res = Mining_solver.play_wall ~goal ~tally w in
    if Mining_wall.is_finished res.wall then incr finished_count;
    if List.mem Mining_goal.Other res.uncovered then incr other_ok
  done;
  assert_eq_int "all non-shard walls finished" n !finished_count;
  assert_true
    (Printf.sprintf
       "expected >= 180/200 (90%%) non-shard walls to recover an item, got \
        %d/%d"
       !other_ok n)
    (!other_ok >= 180);
  Printf.printf
    "Benchmark 200 walls: Shard_l=%d/200 Shard_s=%d/200 Other=%d/200\n%!"
    !shard_l_ok !shard_s_ok !other_ok

let test_layer_aware_scan_and_unwanted_avoidance () =
  let goal = Mining_goal.ramanas_all_slates in
  let tally = Mining_goal.empty_tally in
  (* 1. All Layer-1 shallow dirt: Pickaxe exposes 5/1 > Hammer 9/2. *)
  let shallow =
    Array.init Mining_wall.rows (fun _ ->
        Array.make Mining_wall.cols (Mining_wall.Covered 1))
  in
  (match Mining_solver.decide ~goal ~tally (mk_obs ~integrity:40 shallow) with
  | Mining_solver.Strike { tool = Mining_wall.Pickaxe; _ } -> ()
  | _ -> fail "expected Pickaxe on Layer-1 shallow scan");
  (* 2. All Layer-2 rock: Hammer exposes 5/2 > Pickaxe 1/1. *)
  let mid =
    Array.init Mining_wall.rows (fun _ ->
        Array.make Mining_wall.cols (Mining_wall.Covered 2))
  in
  (match Mining_solver.decide ~goal ~tally (mk_obs ~integrity:40 mid) with
  | Mining_solver.Strike { tool = Mining_wall.Hammer; _ } -> ()
  | _ -> fail "expected Hammer on Layer-2 scan");
  (* 3. Exposed non-wanted item at (2, 2): scan avoids anchor (2, 2). *)
  mid.(2).(2) <- Mining_wall.Clear_item { id = 2; kind = Mining_goal.Other };
  match Mining_solver.decide ~goal ~tally (mk_obs ~integrity:40 mid) with
  | Mining_solver.Strike { col; row; _ } when col <> 2 || row <> 2 -> ()
  | _ -> fail "expected scan to avoid inferred footprint of non-wanted item"

let () =
  test_goal_arithmetic ();
  test_wall_mechanics ();
  test_smart_tool_selection ();
  test_low_gauge_switch ();
  test_layer_aware_scan_and_unwanted_avoidance ();
  test_benchmark_200_walls ();
  print_endline "OK"
