open Bdsp_underground

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq_int label expected actual =
  if expected <> actual then
    fail (Printf.sprintf "%s: expected %d, got %d" label expected actual)

let () =
  let c =
    Mining_counters.empty |> Mining_counters.record_refresh
    |> Mining_counters.record_skipped_corridor |> Mining_counters.record_cycle
    |> Mining_counters.record_refresh
  in
  let c =
    Mining_counters.record_dig c ~bailed:false
      [ Shard_l; Shard_s; Shard_s; Shard_s; Sphere; Fossil ]
  in
  let c =
    Mining_counters.record_dig c ~bailed:true [ Statue_box ]
    |> Mining_counters.record_battle_escaped |> Mining_counters.record_cycle
  in
  assert_eq_int "cycles" 2 c.cycles;
  assert_eq_int "refreshes" 2 c.refreshes;
  assert_eq_int "skipped" 1 c.skipped_corridors;
  assert_eq_int "digs" 2 c.digs;
  assert_eq_int "bailed" 1 c.walls_bailed;
  assert_eq_int "battles" 1 c.battles_escaped;
  assert_eq_int "slates" 2
    (Mining_goal.slate_equivalents (Mining_counters.to_tally c));
  let line =
    Mining_counters.format_summary ~goal:Mining_goal.ramanas_all_slates c
  in
  if not (String.starts_with ~prefix:"cycles=2 refreshes=2 skipped=1" line) then
    fail ("unexpected summary: " ^ line);
  print_endline "OK"
