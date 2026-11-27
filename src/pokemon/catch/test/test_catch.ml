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
    status_setter = Some { slot = 2; move_slot = 1; hp_floor = 0.35 };
    setup = None;
    heavy_chipper = None;
    false_swiper =
      Some { slot = 5; move_slot = 2; require_status = true; hp_floor = 0.40 };
    wall = Some { slot = 3; heal_move_slot = Some 4; hp_floor = 0.45 };
    ball_name = "Luxury Ball";
    fallback_ball = None;
    max_balls = 50;
    foe_hp_target = 0.15;
    foe_hp_rechip = 0.35;
    reapply_status = true;
    max_turns = 80;
    send_in_order = [ 3; 2; 5 ];
  }

let groudon_policy : Catch_state.policy =
  {
    status_setter = Some { slot = 2; move_slot = 1; hp_floor = 0.35 };
    setup = None;
    heavy_chipper = None;
    false_swiper =
      Some { slot = 5; move_slot = 2; require_status = true; hp_floor = 0.40 };
    wall = Some { slot = 6; heal_move_slot = None; hp_floor = 0.40 };
    ball_name = "Luxury Ball";
    fallback_ball = None;
    max_balls = 3;
    foe_hp_target = 0.15;
    foe_hp_rechip = 0.40;
    reapply_status = true;
    max_turns = 60;
    send_in_order = [ 6; 2; 5 ];
  }

let dex_policy : Catch_state.policy =
  {
    status_setter = None;
    setup = None;
    heavy_chipper = None;
    false_swiper = None;
    wall = None;
    ball_name = "Ultra Ball";
    fallback_ball = None;
    max_balls = 20;
    foe_hp_target = 0.15;
    foe_hp_rechip = 0.35;
    reapply_status = false;
    max_turns = 30;
    send_in_order = [ 2; 3 ];
  }

let menu ?(fainted = []) ~active_slot ~active_hp ~foe_hp ~foe_status () =
  Catch_runner.Action_menu
    {
      turn = 0;
      active_slot;
      active_hp_ratio = active_hp;
      foe_hp_ratio = foe_hp;
      foe_status;
      balls_thrown = 0;
      fainted;
      setup_uses_done = 0;
      wall_move_heals_done = 0;
      status_uses_done = 0;
    }

let full_menu ~active_slot ~active_hp ~foe_hp ~foe_status =
  menu ~active_slot ~active_hp:(Some active_hp) ~foe_hp:(Some foe_hp)
    ~foe_status:(Some foe_status) ()

let test_kyogre_full_flow () =
  let events =
    [
      full_menu ~active_slot:1 ~active_hp:1.0 ~foe_hp:1.0 ~foe_status:Healthy;
      full_menu ~active_slot:2 ~active_hp:0.9 ~foe_hp:1.0 ~foe_status:Healthy;
      full_menu ~active_slot:2 ~active_hp:0.9 ~foe_hp:1.0 ~foe_status:Asleep;
      full_menu ~active_slot:5 ~active_hp:0.85 ~foe_hp:1.0 ~foe_status:Asleep;
      full_menu ~active_slot:5 ~active_hp:0.85 ~foe_hp:0.05 ~foe_status:Asleep;
      full_menu ~active_slot:3 ~active_hp:0.90 ~foe_hp:0.05 ~foe_status:Asleep;
      full_menu ~active_slot:3 ~active_hp:0.75 ~foe_hp:0.20 ~foe_status:Healthy;
      full_menu ~active_slot:2 ~active_hp:0.80 ~foe_hp:0.25 ~foe_status:Healthy;
      full_menu ~active_slot:2 ~active_hp:0.80 ~foe_hp:0.40 ~foe_status:Asleep;
      full_menu ~active_slot:5 ~active_hp:0.80 ~foe_hp:0.40 ~foe_status:Asleep;
      full_menu ~active_slot:5 ~active_hp:0.80 ~foe_hp:0.05 ~foe_status:Asleep;
      full_menu ~active_slot:3 ~active_hp:0.30 ~foe_hp:0.05 ~foe_status:Asleep;
      full_menu ~active_slot:3 ~active_hp:0.80 ~foe_hp:0.05 ~foe_status:Asleep;
      Catch_runner.Caught;
    ]
  in
  let steps, recorded = fake_game_steps events in
  let expected_summary : Catch_runner.summary =
    { turns = 13; balls_thrown = 2; switches = 6; heals = 1 }
  in
  assert_eq "kyogre outcome"
    (Catch_runner.run steps kyogre_policy)
    (Catch_runner.Caught expected_summary);
  assert_eq "kyogre actions" (recorded ())
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

let test_groudon_rest_and_forced_switch () =
  let events =
    [
      Catch_runner.Forced_switch { fainted_slot = 2 };
      full_menu ~active_slot:6 ~active_hp:0.95 ~foe_hp:0.05 ~foe_status:Asleep;
      full_menu ~active_slot:6 ~active_hp:0.95 ~foe_hp:1.0 ~foe_status:Asleep;
      full_menu ~active_slot:5 ~active_hp:0.90 ~foe_hp:1.0 ~foe_status:Asleep;
      full_menu ~active_slot:5 ~active_hp:0.90 ~foe_hp:0.05 ~foe_status:Asleep;
      full_menu ~active_slot:6 ~active_hp:0.25 ~foe_hp:0.05 ~foe_status:Asleep;
      full_menu ~active_slot:6 ~active_hp:0.90 ~foe_hp:0.05 ~foe_status:Asleep;
      Catch_runner.Caught;
    ]
  in
  let steps, recorded = fake_game_steps events in
  let expected_summary : Catch_runner.summary =
    { turns = 6; balls_thrown = 2; switches = 3; heals = 1 }
  in
  assert_eq "groudon outcome"
    (Catch_runner.run steps groudon_policy)
    (Catch_runner.Caught expected_summary);
  assert_eq "groudon actions" (recorded ())
    [
      Send_in 6;
      Cmd (Throw_ball "Luxury Ball");
      Cmd (Switch_to 5);
      Cmd (Use_move 2);
      Cmd (Switch_to 6);
      Cmd Heal_active;
      Cmd (Throw_ball "Luxury Ball");
    ]

let test_dex_throw_only () =
  let blind_menu =
    menu ~active_slot:1 ~active_hp:None ~foe_hp:None ~foe_status:None ()
  in
  let events = [ blind_menu; blind_menu; blind_menu; Catch_runner.Caught ] in
  let steps, recorded = fake_game_steps events in
  assert_eq "dex outcome"
    (Catch_runner.run steps dex_policy)
    (Catch_runner.Caught
       { turns = 3; balls_thrown = 3; switches = 0; heals = 0 });
  assert_eq "dex actions" (recorded ())
    [
      Cmd (Throw_ball "Ultra Ball");
      Cmd (Throw_ball "Ultra Ball");
      Cmd (Throw_ball "Ultra Ball");
    ]

let test_mid_battle_fainted_roles () =
  (* Sleeper (2) faints; foe wakes up already chipped -> throws, never switches to 2. *)
  let s1, r1 =
    fake_game_steps
      [
        Catch_runner.Forced_switch { fainted_slot = 2 };
        full_menu ~active_slot:3 ~active_hp:0.9 ~foe_hp:0.05 ~foe_status:Healthy;
        Catch_runner.Caught;
      ]
  in
  assert_eq "fainted sleeper chipped"
    (Catch_runner.run s1 kyogre_policy)
    (Catch_runner.Caught
       { turns = 1; balls_thrown = 1; switches = 1; heals = 0 });
  assert_eq "fainted sleeper chipped actions" (r1 ())
    [ Send_in 3; Cmd (Throw_ball "Luxury Ball") ];
  (* Sleeper (2) faints; foe awake & unchipped with require_status -> pauses cleanly. *)
  let s2, r2 =
    fake_game_steps
      [
        Catch_runner.Forced_switch { fainted_slot = 2 };
        full_menu ~active_slot:3 ~active_hp:0.9 ~foe_hp:1.0 ~foe_status:Healthy;
      ]
  in
  assert_eq "fainted sleeper unchipped"
    (Catch_runner.run s2 kyogre_policy)
    (Catch_runner.Paused
       {
         reason = "need status before false swipe";
         summary = { turns = 0; balls_thrown = 0; switches = 1; heals = 0 };
       });
  assert_eq "fainted sleeper unchipped actions" (r2 ()) [ Send_in 3 ];
  (* False Swiper (5) faints; foe unchipped & paralyzed -> skips chip, throws ball. *)
  let s3, r3 =
    fake_game_steps
      [
        Catch_runner.Forced_switch { fainted_slot = 5 };
        full_menu ~active_slot:3 ~active_hp:0.9 ~foe_hp:1.0
          ~foe_status:Paralyzed;
        Catch_runner.Caught;
      ]
  in
  assert_eq "fainted swiper at full HP pauses"
    (Catch_runner.run s3 kyogre_policy)
    (Catch_runner.Paused
       {
         reason = "foe above HP target and false swiper fainted";
         summary = { turns = 0; balls_thrown = 0; switches = 1; heals = 0 };
       });
  assert_eq "fainted swiper actions" (r3 ()) [ Send_in 3 ];
  (* Wall (3) faints; active False Swiper (5) low HP -> heals in place, then stays & throws. *)
  let s4, r4 =
    fake_game_steps
      [
        Catch_runner.Forced_switch { fainted_slot = 3 };
        full_menu ~active_slot:5 ~active_hp:0.2 ~foe_hp:0.05 ~foe_status:Asleep;
        full_menu ~active_slot:5 ~active_hp:0.9 ~foe_hp:0.05 ~foe_status:Asleep;
        Catch_runner.Caught;
      ]
  in
  assert_eq "fainted wall"
    (Catch_runner.run s4 kyogre_policy)
    (Catch_runner.Caught
       { turns = 2; balls_thrown = 1; switches = 1; heals = 1 });
  assert_eq "fainted wall actions" (r4 ())
    [ Send_in 2; Cmd Heal_active; Cmd (Throw_ball "Luxury Ball") ]

let test_terminal_no_balls_and_foe_ended () =
  let blind =
    menu ~active_slot:1 ~active_hp:None ~foe_hp:None ~foe_status:None ()
  in
  let s1, _ = fake_game_steps [ blind; Catch_runner.No_balls ] in
  assert_eq "no balls outcome"
    (Catch_runner.run s1 dex_policy)
    (Catch_runner.No_balls
       { turns = 1; balls_thrown = 1; switches = 0; heals = 0 });
  let s2, _ = fake_game_steps [ blind; blind; Catch_runner.Foe_ended ] in
  assert_eq "foe ended outcome"
    (Catch_runner.run s2 dex_policy)
    (Catch_runner.Foe_ended
       { turns = 2; balls_thrown = 2; switches = 0; heals = 0 })

let test_limits_and_unexpected () =
  let m =
    full_menu ~active_slot:6 ~active_hp:1.0 ~foe_hp:0.05 ~foe_status:Asleep
  in
  let ball_steps, ball_rec = fake_game_steps [ m; m; m; m ] in
  assert_eq "max_balls pause"
    (Catch_runner.run ball_steps groudon_policy)
    (Catch_runner.Paused
       {
         reason = "ball limit reached (3)";
         summary = { turns = 3; balls_thrown = 3; switches = 0; heals = 0 };
       });
  assert_eq "max_balls no extra action" (List.length (ball_rec ())) 3;
  let turn_policy = { dex_policy with max_turns = 2; max_balls = 10 } in
  let blind =
    menu ~active_slot:1 ~active_hp:None ~foe_hp:None ~foe_status:None ()
  in
  let turn_steps, turn_rec = fake_game_steps [ blind; blind; blind ] in
  assert_eq "max_turns pause"
    (Catch_runner.run turn_steps turn_policy)
    (Catch_runner.Paused
       {
         reason = "turn limit reached (2)";
         summary = { turns = 2; balls_thrown = 2; switches = 0; heals = 0 };
       });
  assert_eq "max_turns no extra action" (List.length (turn_rec ())) 2;
  let unexp_steps, unexp_rec =
    fake_game_steps [ Catch_runner.Unexpected "unknown dialog prompt" ]
  in
  assert_eq "unexpected pause"
    (Catch_runner.run unexp_steps groudon_policy)
    (Catch_runner.Paused
       {
         reason = "unknown dialog prompt";
         summary = Catch_runner.empty_summary;
       });
  assert_eq "unexpected no commands" (unexp_rec ()) [];
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
       })

let test_lead_tank_chip_then_false_swipe_and_balls () =
  let policy : Catch_state.policy =
    {
      status_setter = Some { slot = 1; move_slot = 3; hp_floor = 0.35 };
      setup = None;
      heavy_chipper =
        Some
          {
            slot = 5;
            move_slot = 1;
            hp_floor = 0.40;
            foe_hp_floor = 0.30;
            require_status = true;
          };
      false_swiper =
        Some { slot = 1; move_slot = 2; require_status = true; hp_floor = 0.35 };
      wall = Some { slot = 6; heal_move_slot = None; hp_floor = 0.40 };
      ball_name = "Luxury Ball";
      fallback_ball = None;
      max_balls = 50;
      foe_hp_target = 0.15;
      foe_hp_rechip = 0.35;
      reapply_status = true;
      max_turns = 60;
      send_in_order = [ 6; 1; 5 ];
    }
  in
  let events =
    [
      menu ~active_slot:1 ~active_hp:(Some 1.0) ~foe_hp:(Some 1.0)
        ~foe_status:(Some Catch_state.Healthy) ();
      menu ~active_slot:1 ~active_hp:(Some 1.0) ~foe_hp:(Some 1.0)
        ~foe_status:(Some Catch_state.Asleep) ();
      menu ~active_slot:5 ~active_hp:(Some 1.0) ~foe_hp:(Some 1.0)
        ~foe_status:(Some Catch_state.Asleep) ();
      menu ~active_slot:5 ~active_hp:(Some 1.0) ~foe_hp:(Some 0.65)
        ~foe_status:(Some Catch_state.Asleep) ();
      menu ~active_slot:5 ~active_hp:(Some 1.0) ~foe_hp:(Some 0.30)
        ~foe_status:(Some Catch_state.Asleep) ();
      menu ~active_slot:1 ~active_hp:(Some 1.0) ~foe_hp:(Some 0.30)
        ~foe_status:(Some Catch_state.Asleep) ();
      menu ~active_slot:1 ~active_hp:(Some 1.0) ~foe_hp:(Some 0.10)
        ~foe_status:(Some Catch_state.Asleep) ();
      menu ~active_slot:6 ~active_hp:(Some 1.0) ~foe_hp:(Some 0.10)
        ~foe_status:(Some Catch_state.Asleep) ();
      Catch_runner.Caught;
    ]
  in
  let steps, record = fake_game_steps events in
  let outcome = Catch_runner.run steps policy in
  assert_eq "lead + tank + false_swipe caught" outcome
    (Catch_runner.Caught
       { turns = 8; balls_thrown = 1; switches = 3; heals = 0 });
  assert_eq "lead + tank + false_swipe trace" (record ())
    [
      Cmd (Catch_state.Use_move 3);
      Cmd (Catch_state.Switch_to 5);
      Cmd (Catch_state.Use_move 1);
      Cmd (Catch_state.Use_move 1);
      Cmd (Catch_state.Switch_to 1);
      Cmd (Catch_state.Use_move 2);
      Cmd (Catch_state.Switch_to 6);
      Cmd (Catch_state.Throw_ball "Luxury Ball");
    ]

let test_regression_fainted_swiper_and_status_pp () =
  (* Regression from Console A battle-catch-testing-3 (T54-T56):
     1. When solo Venusaur (status + false swiper + wall) faints and Groudon
        uses Rest back to 100% HP, the policy must pause instead of throwing
        Luxury Balls at full HP.
     2. When Sleep Powder hits 0 PP (15 uses) and foe is already at 10% HP,
        the policy stops clicking move 3 and throws balls directly. *)
  let venusaur_policy : Catch_state.policy =
    {
      status_setter = Some { slot = 1; move_slot = 3; hp_floor = 0.55 };
      setup = Some { slot = 1; move_slot = 4; uses = 2; require_status = true };
      heavy_chipper = None;
      false_swiper =
        Some { slot = 1; move_slot = 2; require_status = true; hp_floor = 0.55 };
      wall = Some { slot = 1; heal_move_slot = Some 1; hp_floor = 0.55 };
      ball_name = "Luxury Ball";
      fallback_ball = None;
      max_balls = 60;
      foe_hp_target = 0.15;
      foe_hp_rechip = 0.35;
      reapply_status = true;
      max_turns = 80;
      send_in_order = [ 1; 2; 3 ];
    }
  in
  let events_rest_after_faint =
    [
      Catch_runner.Forced_switch { fainted_slot = 1 };
      full_menu ~active_slot:2 ~active_hp:1.0 ~foe_hp:1.0
        ~foe_status:Catch_state.Asleep;
    ]
  in
  let steps1, record1 = fake_game_steps events_rest_after_faint in
  let out1 = Catch_runner.run steps1 venusaur_policy in
  (match out1 with
  | Catch_runner.Paused { summary; _ } ->
      assert_eq "no balls thrown at full HP" summary.balls_thrown 0
  | _ -> fail "expected Paused when false swiper fainted and foe at 100% HP");
  assert_eq "forced switch to slot 2 then paused" (record1 ()) [ Send_in 2 ];
  let pp_exhausted_state : Catch_state.t =
    {
      turn = 20;
      active_slot = 1;
      active_hp_ratio = Some 0.9;
      foe_hp_ratio = Some 0.10;
      foe_status = Some Catch_state.Healthy;
      balls_thrown = 5;
      fainted = [];
      setup_uses_done = 2;
      wall_move_heals_done = 5;
      status_uses_done = 15;
    }
  in
  assert_eq "status 0 PP throws ball at 10% HP"
    (Catch_policy.decide venusaur_policy pp_exhausted_state)
    (Catch_state.Throw_ball "Luxury Ball");
  let low_hp_after_5_heals =
    { pp_exhausted_state with active_hp_ratio = Some 0.40 }
  in
  assert_eq "wall heal 0 PP falls back to Heal_active"
    (Catch_policy.decide venusaur_policy low_hp_after_5_heals)
    Catch_state.Heal_active;
  let fallback_policy =
    { venusaur_policy with fallback_ball = Some (25, "Dusk Ball") }
  in
  let late_turn_state = { pp_exhausted_state with turn = 25 } in
  assert_eq "turn >= 25 switches to fallback Dusk Ball"
    (Catch_policy.decide fallback_policy late_turn_state)
    (Catch_state.Throw_ball "Dusk Ball")

let () =
  test_kyogre_full_flow ();
  test_groudon_rest_and_forced_switch ();
  test_dex_throw_only ();
  test_mid_battle_fainted_roles ();
  test_terminal_no_balls_and_foe_ended ();
  test_limits_and_unexpected ();
  test_lead_tank_chip_then_false_swipe_and_balls ();
  test_regression_fainted_swiper_and_status_pp ();
  print_endline "OK"
