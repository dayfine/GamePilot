(* Scripted unit tests for Bdsp_actions.Battle_catch_steps.
   Fakes stand in for the daemon effect handler: an Effect.Deep handler feeds
   synthetic Wire.frame measurements (battle menu, dialog, forced switch, black
   screen) and records every submitted Wire.button press so we can verify both
   catch-loop execution and the never-press-Run safety invariant. *)

open Pokemon_catch
open Bdsp_actions

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq label actual expected =
  if actual <> expected then fail (label ^ ": mismatch")

let cs (r, g, b) (sr, sg, sb) =
  Wire.Color_stats
    { mean = { Wire.r; g; b }; stddev = { Wire.r = sr; g = sg; b = sb } }

let hp_probes prefix ~filled ~rgb =
  List.init 10 (fun idx ->
      let id = Printf.sprintf "%s%d" prefix idx in
      let color = if idx < filled then rgb else (35., 35., 38.) in
      (id, cs color (4., 4., 4.)))

let menu_frame ~t_ms ~foe_filled ~player_filled ~asleep : Effects.measurements =
  let sleep_probe =
    if asleep then ("bdsp_foe_slp", cs (121., 174., 225.) (12., 12., 12.))
    else ("bdsp_foe_slp", cs (245., 245., 245.) (3., 3., 3.))
  in
  {
    Wire.seq = 1;
    t_ms;
    probes =
      [
        ("bdsp_battle_menu_fight", cs (217., 92., 91.) (20., 20., 20.));
        ("bdsp_battle_menu_run", cs (76., 144., 180.) (20., 20., 20.));
        sleep_probe;
      ]
      @ hp_probes "bdsp_foe_hp_" ~filled:foe_filled ~rgb:(50., 210., 70.)
      @ hp_probes "bdsp_ply_hp_" ~filled:player_filled ~rgb:(50., 210., 70.);
  }

let dialog_frame ~t_ms : Effects.measurements =
  {
    Wire.seq = 2;
    t_ms;
    probes =
      [
        ("bdsp_dlg_lw", cs (250., 250., 250.) (1., 1., 1.));
        ("bdsp_dlg_rw", cs (250., 250., 250.) (1., 1., 1.));
        ("bdsp_dlg_l", cs (180., 180., 180.) (20., 20., 20.));
        ("bdsp_dlg_r", cs (180., 180., 180.) (20., 20., 20.));
      ];
  }

let black_frame ~t_ms : Effects.measurements =
  {
    Wire.seq = 3;
    t_ms;
    probes = [ ("start_game.black", cs (5., 5., 5.) (1., 1., 1.)) ];
  }

let clear_frame ~t_ms : Effects.measurements =
  {
    Wire.seq = 4;
    t_ms;
    probes = [ ("start_game.black", cs (200., 200., 200.) (10., 10., 10.)) ];
  }

let run_scripted frames f =
  let queue = Queue.of_seq (List.to_seq frames) in
  let now = ref 0. in
  let presses = ref [] in
  let record_cmds cmds =
    List.iter
      (function
        | Wire.Press { buttons; _ } ->
            presses := List.rev_append buttons !presses
        | Wire.Wait _ -> ())
      cmds
  in
  let effc : type a. a Effect.t -> ((a, _) Effect.Deep.continuation -> _) option
      = function
    | Effects.Subscribe specs ->
        Some
          (fun k ->
            let ids = List.map (fun (s : Wire.probe_spec) -> s.id) specs in
            Effect.Deep.continue k ids)
    | Effects.Now -> Some (fun k -> Effect.Deep.continue k !now)
    | Effects.Submit cmds ->
        Some
          (fun k ->
            record_cmds cmds;
            now := !now +. 100.;
            Effect.Deep.continue k { Wire.batch_id = "b"; seq = 1; t_ms = !now })
    | Effects.Await (pred, timeout_ms) ->
        Some
          (fun k ->
            let rec next () =
              match Queue.take_opt queue with
              | None ->
                  now := !now +. float_of_int timeout_ms;
                  Effects.Timeout
              | Some (m : Effects.measurements) ->
                  now := m.t_ms;
                  if pred m then Effects.Holds m else next ()
            in
            Effect.Deep.continue k (next ()))
    | _ -> None
  in
  let res = Effect.Deep.try_with f () { effc } in
  (res, List.rev !presses)

let test_cfg : Battle_catch_steps.config =
  {
    picture = { x = 0.; y = 0.; w = 1.; h = 1. };
    initial_active_slot = 2;
    bag =
      {
        ball_pocket_steps = 1;
        ball_row = 2;
        heal_pocket_steps = 0;
        heal_row = 0;
      };
    timing =
      {
        Battle_catch_steps.default_timing with
        event_timeout_ms = 2000;
        status_cycle_ms = 0;
      };
  }

let kyogre_slots : Battle_catch_steps.party_slots =
  {
    status_setter = 2;
    status_move = 1;
    false_swiper = 5;
    false_swipe_move = 2;
    wall = 3;
    wall_heal_move = Some 4;
    send_in_order = [ 3; 2; 5 ];
  }

let test_scripted_kyogre_catch () =
  let frames =
    [
      (* Turn 1: Venusaur (2) vs awake full-HP Kyogre -> Sleep Powder (move 1). *)
      menu_frame ~t_ms:100. ~foe_filled:10 ~player_filled:10 ~asleep:false;
      (* Dialog between turns -> advances with A. *)
      dialog_frame ~t_ms:200.;
      (* Turn 2: Kyogre asleep, still full HP -> switch to Garchomp (5). *)
      menu_frame ~t_ms:300. ~foe_filled:10 ~player_filled:10 ~asleep:true;
      (* Turn 3: Garchomp (5) uses False Swipe (move 2). *)
      menu_frame ~t_ms:400. ~foe_filled:10 ~player_filled:10 ~asleep:true;
      (* Turn 4: Kyogre at 10% HP (<= 0.15) -> fragile Garchomp switches to Milotic (3). *)
      menu_frame ~t_ms:500. ~foe_filled:1 ~player_filled:10 ~asleep:true;
      (* Turn 5: Milotic (3) throws Luxury Ball. *)
      menu_frame ~t_ms:600. ~foe_filled:1 ~player_filled:10 ~asleep:true;
      (* Battle fades to black and clears -> Caught! *)
      black_frame ~t_ms:700.;
      clear_frame ~t_ms:1000.;
      clear_frame ~t_ms:1300.;
    ]
  in
  let policy = Battle_catch_steps.kyogre_policy kyogre_slots in
  let outcome, presses =
    run_scripted frames (fun () ->
        let steps = Battle_catch_steps.make test_cfg in
        Catch_runner.run steps policy)
  in
  let expected_summary : Catch_runner.summary =
    { turns = 5; balls_thrown = 1; switches = 2; heals = 0 }
  in
  assert_eq "scripted kyogre caught" outcome
    (Catch_runner.Caught expected_summary);
  (* Safety invariant: never press Up (which wraps to Run from Fight). *)
  assert_eq "never presses Up" (List.mem Wire.Up presses) false

let test_timeout_pauses_safely () =
  let policy = Battle_catch_steps.groudon_policy kyogre_slots in
  let outcome, presses =
    run_scripted [] (fun () ->
        let steps = Battle_catch_steps.make test_cfg in
        Catch_runner.run steps policy)
  in
  assert_eq "timeout pauses safely" outcome
    (Catch_runner.Paused
       {
         reason = "timed out waiting for BDSP battle event";
         summary = Catch_runner.empty_summary;
       });
  assert_eq "timeout submits no presses" presses []

let () =
  test_scripted_kyogre_catch ();
  test_timeout_pauses_safely ();
  print_endline "OK"
