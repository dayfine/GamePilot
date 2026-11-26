open Bdsp_underground

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq_int label expected actual =
  if expected <> actual then
    fail (Printf.sprintf "%s: expected %d, got %d" label expected actual)

let fake_game_steps ~dig_script ~battle_on_walk_idx ~battle_on_refresh_idx =
  let walk_calls = ref 0 in
  let dig_idx = ref 0 in
  let refresh_calls = ref 0 in
  let steps =
    {
      Corridor_nav.pulse_radar =
        (fun () ->
          Ok
            [
              { Corridor_nav.offset_tiles = 3; wall_side = North };
              { Corridor_nav.offset_tiles = 7; wall_side = South };
            ]);
      walk_to_sparkle =
        (fun _ ->
          incr walk_calls;
          if !walk_calls = battle_on_walk_idx then Ok Corridor_nav.Wild_battle
          else Ok Corridor_nav.At_wall);
      dig_wall =
        (fun () ->
          let idx = !dig_idx in
          incr dig_idx;
          if idx < Array.length dig_script then Ok dig_script.(idx)
          else Ok ([ Mining_goal.Other ], true));
      bounce_hideaway_door =
        (fun _ ->
          incr refresh_calls;
          if !refresh_calls = battle_on_refresh_idx then
            Ok Corridor_nav.Refresh_wild_battle
          else Ok Corridor_nav.Refreshed);
      run_from_battle = (fun () -> Ok ());
      save_game = (fun () -> Ok ());
    }
  in
  steps

let test_session_reaches_goal_with_refresh_and_battle_recovery () =
  let script =
    [|
      ([ Mining_goal.Other ], true);
      ([ Mining_goal.Shard_s ], false);
      ([ Mining_goal.Shard_s; Mining_goal.Shard_s ], false);
      ([ Mining_goal.Shard_l ], false);
    |]
  in
  let steps =
    fake_game_steps ~dig_script:script ~battle_on_walk_idx:2
      ~battle_on_refresh_idx:1
  in
  let anchor = { Corridor_nav.enter_dir = North; exit_dir = South } in
  match
    Corridor_nav.run_session ~goal:(Mining_goal.Slates 2) ~anchor ~save_every:2
      ~max_refreshes:10 ~steps
  with
  | Error e -> fail ("session failed: " ^ e)
  | Ok summary ->
      assert_eq_int "slate equivalents" 2
        (Mining_goal.slate_equivalents summary.tally);
      assert_eq_int "digs" 4 summary.tally.digs;
      assert_eq_int "bailed" 1 summary.tally.walls_bailed;
      assert_eq_int "battles escaped" 2 summary.battles_escaped;
      assert_eq_int "saves" 2 summary.saves;
      assert_eq_int "move mechanics turn tap" 50
        Corridor_nav.bdsp_move_mechanics.turn_tap_ms

let () =
  test_session_reaches_goal_with_refresh_and_battle_recovery ();
  print_endline "OK"
