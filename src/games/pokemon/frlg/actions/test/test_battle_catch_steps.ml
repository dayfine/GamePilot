(* Scripted Effect.Deep typed unit tests for Frlg_actions.Battle_catch_steps.
   An Effect.Deep handler feeds synthetic Battle_hud + Battle_screen frames on
   Effects.Read and records probe subscriptions, while a scripted fake
   Frlg_battle.Battle.game_steps records every action and verifies the
   never-call-Run safety invariant across Phase 1 (2-mon) and Phase 2 (1-mon)
   catch policies. *)

open Pokemon_catch
open Frlg_actions
module B = Frlg_battle.Battle
module Bag = Frlg_readers.Bag_screen

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq label actual expected =
  if actual <> expected then fail (label ^ ": mismatch")

let cs (r, g, b) (sr, sg, sb) =
  Wire.Color_stats
    { mean = { Wire.r; g; b }; stddev = { Wire.r = sr; g = sg; b = sb } }

let foe_box_probes =
  let light = cs (245., 245., 235.) (2., 2., 2.) in
  let dark = cs (80., 95., 90.) (2., 2., 2.) in
  let bg = cs (80., 140., 220.) (4., 4., 4.) in
  [
    ("battle.foe.left", light);
    ("battle.foe.right", light);
    ("battle.foe.top", light);
    ("battle.foe.bottom", dark);
    ("battle.foe.background", bg);
  ]

let player_box_probes =
  let light = cs (245., 245., 235.) (2., 2., 2.) in
  let dark = cs (80., 95., 90.) (2., 2., 2.) in
  let bg = cs (80., 140., 220.) (4., 4., 4.) in
  [
    ("battle.player.left", light);
    ("battle.player.right", dark);
    ("battle.player.top", light);
    ("battle.player.bottom", dark);
    ("battle.player.background", bg);
  ]

let hp_probes prefix ~filled ~rgb =
  List.init 12 (fun idx ->
      let id = Printf.sprintf "%s%d" prefix idx in
      let color = if idx < filled then rgb else (72., 88., 88.) in
      (id, cs color (3., 3., 3.)))

let hud_frame ~foe_filled ~player_filled ~asleep : Effects.measurements =
  let status_rgb = if asleep then (148., 152., 148.) else (255., 255., 222.) in
  {
    Wire.seq = 1;
    t_ms = 0.;
    probes =
      foe_box_probes @ player_box_probes
      @ [ ("battle.hud.foe_status", cs status_rgb (5., 5., 5.)) ]
      @ hp_probes "battle.hud.foe_hp." ~filled:foe_filled ~rgb:(80., 240., 128.)
      @ hp_probes "battle.hud.player_hp." ~filled:player_filled
          ~rgb:(80., 240., 128.);
  }

type recorded_action =
  | Move of int
  | Switch of int
  | Send_in of int
  | Item of (Bag.pocket * int * int option)
  | Answer_use_next of bool
  | Run

let make_fake_battle ?(item_ok = true) events =
  let remaining = ref events in
  let actions = ref [] in
  let log_action a = actions := a :: !actions in
  let level_up : Frlg_battle.Level_up.game_steps =
    {
      next = (fun () -> Frlg_battle.Level_up.Back);
      open_list = (fun () -> false);
      read_list = (fun () -> { offered = None; known = [] });
      forget = (fun _ -> false);
      leave_list = (fun () -> false);
      decline = (fun () -> false);
      evolution = (fun ~cancel:_ -> Frlg_battle.Level_up.Ended);
      log = ignore;
    }
  in
  let steps : B.game_steps =
    {
      next_event =
        (fun ~timeout_ms:_ ->
          match !remaining with
          | [] -> B.Timed_out
          | ev :: rest ->
              remaining := rest;
              ev);
      use_move =
        (fun ~slot ~target:_ ~expect:_ ->
          log_action (Move slot);
          B.Chosen);
      switch_to =
        (fun ~slot ->
          log_action (Switch slot);
          true);
      send_in =
        (fun ~slot ->
          log_action (Send_in slot);
          true);
      run = (fun () -> log_action Run);
      use_item =
        (fun (item : B.item) ->
          log_action (Item (item.pocket, item.row, item.on_slot));
          item_ok);
      level_up;
      answer_use_next = (fun yes -> log_action (Answer_use_next yes));
    }
  in
  (steps, fun () -> List.rev !actions)

let run_with_hud frames f =
  let remaining = ref frames in
  let subscribed = ref 0 in
  let effc : type a. a Effect.t -> ((a, _) Effect.Deep.continuation -> _) option
      = function
    | Effects.Subscribe specs ->
        Some
          (fun k ->
            subscribed := !subscribed + List.length specs;
            let ids = List.map (fun (s : Wire.probe_spec) -> s.id) specs in
            Effect.Deep.continue k ids)
    | Effects.Read ->
        Some
          (fun k ->
            let cur =
              match !remaining with
              | [] -> None
              | hd :: tl ->
                  remaining := tl;
                  Some hd
            in
            Effect.Deep.continue k cur)
    | _ -> None
  in
  let res = Effect.Deep.try_with f () { effc } in
  (res, !subscribed)

let test_cfg : Battle_catch_steps.config =
  {
    initial_active_slot = 1;
    bag = { ball_row = 2; heal_row = 0 };
    event_timeout_ms = 5000;
  }

let test_phase1_two_mon_catch () =
  let events =
    [
      B.Action_menu;
      B.Action_menu;
      B.Action_menu;
      B.Action_menu;
      B.Action_menu;
      B.Battle_over;
    ]
  in
  let frames =
    [
      (* Turn 1: Slot 1 (Parasect) vs awake full HP -> Spore (move 0). *)
      hud_frame ~foe_filled:12 ~player_filled:12 ~asleep:false;
      (* Turn 2: asleep full HP -> switch to Slot 2 (0-based 1). *)
      hud_frame ~foe_filled:12 ~player_filled:12 ~asleep:true;
      (* Turn 3: Slot 2 (Farfetch'd) uses False Swipe (move 0). *)
      hud_frame ~foe_filled:12 ~player_filled:12 ~asleep:true;
      (* Turn 4: foe at 1/12 HP -> retreat to wall Slot 1, which swapped into
         battle party position 1 when Slot 2 switched in. *)
      hud_frame ~foe_filled:1 ~player_filled:12 ~asleep:true;
      (* Turn 5: Slot 1 throws Luxury Ball (Poke_balls row 2). *)
      hud_frame ~foe_filled:1 ~player_filled:12 ~asleep:true;
    ]
  in
  let battle, get_actions = make_fake_battle events in
  let policy =
    Battle_catch_steps.phase1_policy ~ball_name:"luxury-ball"
      Battle_catch_steps.default_phase1_slots
  in
  let outcome, sub_count =
    run_with_hud frames (fun () ->
        let steps = Battle_catch_steps.make ~battle test_cfg in
        Catch_runner.run steps policy)
  in
  assert_eq "phase1 caught" outcome
    (Catch_runner.Caught
       { turns = 5; balls_thrown = 1; switches = 2; heals = 0 });
  assert_eq "phase1 actions" (get_actions ())
    [ Move 0; Switch 1; Move 0; Switch 1; Item (Bag.Poke_balls, 2, None) ];
  assert_eq "never calls Run" (List.mem Run (get_actions ())) false;
  assert_eq "probes subscribed once" (sub_count > 0) true

let test_phase2_one_mon_catch () =
  let events = [ B.Action_menu; B.Action_menu; B.Action_menu; B.Battle_over ] in
  let frames =
    [
      (* Turn 1: Slot 1 (Parasect) uses Spore (move 0). *)
      hud_frame ~foe_filled:12 ~player_filled:12 ~asleep:false;
      (* Turn 2: Slot 1 uses False Swipe (move 1), zero switches. *)
      hud_frame ~foe_filled:12 ~player_filled:12 ~asleep:true;
      (* Turn 3: Slot 1 throws Ultra Ball directly. *)
      hud_frame ~foe_filled:1 ~player_filled:12 ~asleep:true;
    ]
  in
  let battle, get_actions = make_fake_battle events in
  let policy =
    Battle_catch_steps.phase2_policy Battle_catch_steps.default_phase2_slots
  in
  let outcome, _ =
    run_with_hud frames (fun () ->
        let steps = Battle_catch_steps.make ~battle test_cfg in
        Catch_runner.run steps policy)
  in
  assert_eq "phase2 caught" outcome
    (Catch_runner.Caught
       { turns = 3; balls_thrown = 1; switches = 0; heals = 0 });
  assert_eq "phase2 actions" (get_actions ())
    [ Move 0; Move 1; Item (Bag.Poke_balls, 2, None) ]

let test_use_next_and_forced_switch () =
  let events = [ B.Use_next; B.Switch_in; B.Action_menu; B.Battle_over ] in
  let frames = [ hud_frame ~foe_filled:1 ~player_filled:12 ~asleep:true ] in
  let battle, get_actions = make_fake_battle events in
  let policy =
    Battle_catch_steps.phase1_policy
      {
        Battle_catch_steps.default_phase1_slots with
        use_sleeper_as_wall = false;
      }
  in
  let outcome, _ =
    run_with_hud frames (fun () ->
        let steps = Battle_catch_steps.make ~battle test_cfg in
        Catch_runner.run steps policy)
  in
  assert_eq "forced switch caught" outcome
    (Catch_runner.Caught
       { turns = 1; balls_thrown = 1; switches = 1; heals = 0 });
  assert_eq "answers YES to Use_next and sends in slot 2 (0-based 1)"
    (get_actions ())
    [ Answer_use_next true; Send_in 1; Item (Bag.Poke_balls, 2, None) ]

let test_no_balls_and_foe_ended_and_pause () =
  (* No_balls when bag use_item returns false. *)
  let battle_nb, _ = make_fake_battle ~item_ok:false [ B.Action_menu ] in
  let policy =
    Battle_catch_steps.phase2_policy Battle_catch_steps.default_phase2_slots
  in
  let outcome_nb, _ =
    run_with_hud
      [ hud_frame ~foe_filled:1 ~player_filled:12 ~asleep:true ]
      (fun () ->
        Catch_runner.run
          (Battle_catch_steps.make ~battle:battle_nb test_cfg)
          policy)
  in
  assert_eq "no balls outcome" outcome_nb
    (Catch_runner.No_balls
       { turns = 1; balls_thrown = 1; switches = 0; heals = 0 });
  (* Foe_ended when Battle_over occurs without throwing a ball. *)
  let battle_fe, _ = make_fake_battle [ B.Battle_over ] in
  let outcome_fe, _ =
    run_with_hud [] (fun () ->
        Catch_runner.run
          (Battle_catch_steps.make ~battle:battle_fe test_cfg)
          policy)
  in
  assert_eq "foe ended outcome" outcome_fe
    (Catch_runner.Foe_ended Catch_runner.empty_summary);
  (* Timed_out pauses safely. *)
  let battle_to, _ = make_fake_battle [ B.Timed_out ] in
  let outcome_to, _ =
    run_with_hud [] (fun () ->
        Catch_runner.run
          (Battle_catch_steps.make ~battle:battle_to test_cfg)
          policy)
  in
  assert_eq "timeout pauses safely" outcome_to
    (Catch_runner.Paused
       {
         reason = "timed out waiting for FRLG battle event";
         summary = Catch_runner.empty_summary;
       })

let () =
  test_phase1_two_mon_catch ();
  test_phase2_one_mon_catch ();
  test_use_next_and_forced_switch ();
  test_no_balls_and_foe_ended_and_pause ();
  print_endline "OK"
