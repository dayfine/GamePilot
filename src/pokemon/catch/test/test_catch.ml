(* Unit tests for Pokemon_catch (Catch_policy and Catch_runner).
   Fakes stand in for a live battle's game_steps: a scripted queue of battle
   events paired with a recorder of every Catch_state.command and forced
   send-in slot, verifying whole-value outcomes and command traces without
   driving a console. *)

open Pokemon_catch

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq label actual expected =
  if actual <> expected then fail (label ^ ": mismatch")

type recorded_action = Cmd of Catch_state.command | Send_in of int

let fake_game_steps events =
  let queue = Queue.of_seq (List.to_seq events) in
  let actions = ref [] in
  let steps : Catch_runner.game_steps =
    {
      next_event =
        (fun () ->
          match Queue.take_opt queue with
          | Some ev -> Ok ev
          | None -> Ok (Catch_runner.Unexpected "script exhausted"));
      execute =
        (fun cmd ->
          actions := Cmd cmd :: !actions;
          Ok ());
      send_in =
        (fun slot ->
          actions := Send_in slot :: !actions;
          Ok ());
    }
  in
  (steps, fun () -> List.rev !actions)

let kyogre_policy : Catch_state.policy =
  {
    sleeper = Some { slot = 2; move_slot = 1; hp_floor = 0.35 };
    false_swiper =
      Some { slot = 5; move_slot = 2; require_sleep = true; hp_floor = 0.40 };
    wall = { slot = 3; heal_move_slot = Some 4; hp_floor = 0.45 };
    ball_name = "Luxury Ball";
    max_balls = 50;
    foe_hp_target = 0.15;
    foe_hp_rechip = 0.35;
    reapply_sleep = true;
    max_turns = 80;
    send_in_order = [ 3; 2; 5 ];
  }

let groudon_policy : Catch_state.policy =
  {
    sleeper = Some { slot = 2; move_slot = 1; hp_floor = 0.35 };
    false_swiper =
      Some { slot = 5; move_slot = 2; require_sleep = true; hp_floor = 0.40 };
    wall = { slot = 6; heal_move_slot = None; hp_floor = 0.40 };
    ball_name = "Luxury Ball";
    max_balls = 3;
    foe_hp_target = 0.15;
    foe_hp_rechip = 0.40;
    reapply_sleep = true;
    max_turns = 60;
    send_in_order = [ 6; 2; 5 ];
  }

let menu ~active_slot ~active_hp ~foe_hp ~foe_asleep =
  Catch_runner.Action_menu
    {
      turn = 0;
      active_slot;
      active_hp_ratio = active_hp;
      foe_hp_ratio = foe_hp;
      foe_asleep;
      balls_thrown = 0;
    }

let test_kyogre_full_flow () =
  let events =
    [
      (* Lead slot 1 opens vs full-HP awake Kyogre -> switch to Venusaur (2). *)
      menu ~active_slot:1 ~active_hp:1.0 ~foe_hp:1.0 ~foe_asleep:false;
      (* Venusaur puts Kyogre to sleep -> Use_move 1. *)
      menu ~active_slot:2 ~active_hp:0.9 ~foe_hp:1.0 ~foe_asleep:false;
      (* Kyogre asleep at full HP -> switch to Garchomp (5). *)
      menu ~active_slot:2 ~active_hp:0.9 ~foe_hp:1.0 ~foe_asleep:true;
      (* Garchomp chips with False Swipe -> Use_move 2. *)
      menu ~active_slot:5 ~active_hp:0.85 ~foe_hp:1.0 ~foe_asleep:true;
      (* Kyogre now at 1 HP (0.05) and asleep; fragile Garchomp retreats to
         Milotic (3) before throwing balls. *)
      menu ~active_slot:5 ~active_hp:0.85 ~foe_hp:0.05 ~foe_asleep:true;
      (* Milotic throws Luxury Ball. *)
      menu ~active_slot:3 ~active_hp:0.90 ~foe_hp:0.05 ~foe_asleep:true;
      (* Kyogre wakes up -> switch to Venusaur (2) to re-sleep. *)
      menu ~active_slot:3 ~active_hp:0.75 ~foe_hp:0.20 ~foe_asleep:false;
      (* Venusaur uses Sleep Powder. *)
      menu ~active_slot:2 ~active_hp:0.80 ~foe_hp:0.25 ~foe_asleep:false;
      (* Aqua Ring healed Kyogre to 0.40 (> foe_hp_rechip 0.35) -> switch to
         Garchomp (5) to re-chip. *)
      menu ~active_slot:2 ~active_hp:0.80 ~foe_hp:0.40 ~foe_asleep:true;
      (* Garchomp False Swipes back down. *)
      menu ~active_slot:5 ~active_hp:0.80 ~foe_hp:0.40 ~foe_asleep:true;
      (* Retreat Garchomp to Milotic (3). *)
      menu ~active_slot:5 ~active_hp:0.80 ~foe_hp:0.05 ~foe_asleep:true;
      (* Milotic is low (0.30 < 0.45) -> Recover (move 4). *)
      menu ~active_slot:3 ~active_hp:0.30 ~foe_hp:0.05 ~foe_asleep:true;
      (* Milotic healthy again -> throw Luxury Ball and catch! *)
      menu ~active_slot:3 ~active_hp:0.80 ~foe_hp:0.05 ~foe_asleep:true;
      Catch_runner.Caught;
    ]
  in
  let steps, recorded = fake_game_steps events in
  let outcome = Catch_runner.run steps kyogre_policy in
  let expected_summary : Catch_runner.summary =
    { turns = 13; balls_thrown = 2; switches = 6; heals = 1 }
  in
  assert_eq "kyogre outcome" outcome (Catch_runner.Caught expected_summary);
  let expected_actions =
    [
      Cmd (Switch_to 2);
      Cmd (Use_move 1);
      Cmd (Switch_to 5);
      Cmd (Use_move 2);
      Cmd (Switch_to 3);
      Cmd (Throw_ball "Luxury Ball");
      Cmd (Switch_to 2);
      Cmd (Use_move 1);
      Cmd (Switch_to 5);
      Cmd (Use_move 2);
      Cmd (Switch_to 3);
      Cmd (Use_move 4);
      Cmd (Throw_ball "Luxury Ball");
    ]
  in
  assert_eq "kyogre actions" (recorded ()) expected_actions

let test_groudon_rest_and_forced_switch () =
  let events =
    [
      (* Venusaur faints before switching -> forced switch sends Aerodactyl (6). *)
      Catch_runner.Forced_switch { fainted_slot = 2 };
      (* Aerodactyl throws Luxury Ball at sleeping 1-HP Groudon. *)
      menu ~active_slot:6 ~active_hp:0.95 ~foe_hp:0.05 ~foe_asleep:true;
      (* Groudon used Rest (1.0 HP, asleep) -> re-chip with Garchomp (5). *)
      menu ~active_slot:6 ~active_hp:0.95 ~foe_hp:1.0 ~foe_asleep:true;
      menu ~active_slot:5 ~active_hp:0.90 ~foe_hp:1.0 ~foe_asleep:true;
      (* Retreat Garchomp to Aerodactyl (6), then heal when low (no heal move). *)
      menu ~active_slot:5 ~active_hp:0.90 ~foe_hp:0.05 ~foe_asleep:true;
      menu ~active_slot:6 ~active_hp:0.25 ~foe_hp:0.05 ~foe_asleep:true;
      (* Throw Luxury Ball and catch. *)
      menu ~active_slot:6 ~active_hp:0.90 ~foe_hp:0.05 ~foe_asleep:true;
      Catch_runner.Caught;
    ]
  in
  let steps, recorded = fake_game_steps events in
  let outcome = Catch_runner.run steps groudon_policy in
  let expected_summary : Catch_runner.summary =
    { turns = 6; balls_thrown = 2; switches = 3; heals = 1 }
  in
  assert_eq "groudon outcome" outcome (Catch_runner.Caught expected_summary);
  let expected_actions =
    [
      Send_in 6;
      Cmd (Throw_ball "Luxury Ball");
      Cmd (Switch_to 5);
      Cmd (Use_move 2);
      Cmd (Switch_to 6);
      Cmd Heal_active;
      Cmd (Throw_ball "Luxury Ball");
    ]
  in
  assert_eq "groudon actions" (recorded ()) expected_actions

let test_pauses_safely_on_limits_and_unexpected () =
  (* Max balls limit (3) pauses on the 4th action menu. *)
  let ball_events =
    [
      menu ~active_slot:6 ~active_hp:1.0 ~foe_hp:0.05 ~foe_asleep:true;
      menu ~active_slot:6 ~active_hp:1.0 ~foe_hp:0.05 ~foe_asleep:true;
      menu ~active_slot:6 ~active_hp:1.0 ~foe_hp:0.05 ~foe_asleep:true;
      menu ~active_slot:6 ~active_hp:1.0 ~foe_hp:0.05 ~foe_asleep:true;
    ]
  in
  let steps, _ = fake_game_steps ball_events in
  assert_eq "max_balls pause"
    (Catch_runner.run steps groudon_policy)
    (Catch_runner.Paused
       {
         reason = "ball limit reached (3)";
         summary = { turns = 3; balls_thrown = 3; switches = 0; heals = 0 };
       });
  (* Unexpected screen pauses immediately without throwing or fleeing. *)
  let unexp_steps, unexp_recorded =
    fake_game_steps [ Catch_runner.Unexpected "unknown dialog prompt" ]
  in
  assert_eq "unexpected pause"
    (Catch_runner.run unexp_steps groudon_policy)
    (Catch_runner.Paused
       {
         reason = "unknown dialog prompt";
         summary = Catch_runner.empty_summary;
       });
  assert_eq "unexpected no commands" (unexp_recorded ()) [];
  (* Exhausted send-in list pauses cleanly. *)
  let faint_steps, _ =
    fake_game_steps
      [
        Catch_runner.Forced_switch { fainted_slot = 6 };
        Catch_runner.Forced_switch { fainted_slot = 2 };
        Catch_runner.Forced_switch { fainted_slot = 5 };
      ]
  in
  assert_eq "no send-in pause"
    (Catch_runner.run faint_steps groudon_policy)
    (Catch_runner.Paused
       {
         reason = "no healthy send-in left";
         summary = { turns = 0; balls_thrown = 0; switches = 2; heals = 0 };
       });
  (* require_sleep without a sleeper pauses instead of risking False Swiper. *)
  let no_sleeper = { kyogre_policy with sleeper = None } in
  let state : Catch_state.t =
    {
      turn = 0;
      active_slot = 5;
      active_hp_ratio = 1.0;
      foe_hp_ratio = 1.0;
      foe_asleep = false;
      balls_thrown = 0;
    }
  in
  assert_eq "require_sleep without sleeper"
    (Catch_policy.decide no_sleeper state)
    (Catch_state.Pause_for_user "need sleep before false swipe")

let () =
  test_kyogre_full_flow ();
  test_groudon_rest_and_forced_switch ();
  test_pauses_safely_on_limits_and_unexpected ();
  print_endline "OK"
