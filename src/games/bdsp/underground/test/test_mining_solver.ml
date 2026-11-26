open Bdsp_underground

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq_int label expected actual =
  if expected <> actual then
    fail (Printf.sprintf "%s: expected %d, got %d" label expected actual)

let assert_true label cond =
  if not cond then fail label

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
  let dirt = Array.init Mining_wall.rows (fun _ -> Array.make Mining_wall.cols 2) in
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

let test_solver_uncovers_shards_and_bails_on_junk () =
  let goal = Mining_goal.ramanas_all_slates in
  let tally = Mining_goal.empty_tally in
  let shard_walls = 100 in
  let recovered = ref 0 in
  for seed = 1 to shard_walls do
    let w =
      Mining_wall.generate ~seed
        ~items:[ Mining_goal.Shard_l; Mining_goal.Other; Mining_goal.Other ]
    in
    let res = Mining_solver.play_wall ~goal ~tally w in
    if List.mem Mining_goal.Shard_l res.uncovered then incr recovered
  done;
  assert_true
    (Printf.sprintf "expected >= 85/100 Shard L recovery, got %d" !recovered)
    (!recovered >= 85);
  let junk_walls = 50 in
  let bailed_count = ref 0 in
  for seed = 1001 to 1000 + junk_walls do
    let w =
      Mining_wall.generate ~seed
        ~items:[ Mining_goal.Other; Mining_goal.Other ]
    in
    let res = Mining_solver.play_wall ~goal ~tally w in
    if res.bailed then incr bailed_count
  done;
  assert_true
    (Printf.sprintf "expected >= 45/50 junk walls bailed, got %d" !bailed_count)
    (!bailed_count >= 45)

let () =
  test_goal_arithmetic ();
  test_wall_mechanics ();
  test_solver_uncovers_shards_and_bails_on_junk ();
  print_endline "OK"
