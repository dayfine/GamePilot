(* Tests for Bdsp_engine: plan decoding, unknown-field rejection, runner
   dispatch, and event snapshot round-tripping. The fake Game.t records
   dispatched BDSP actions without talking to a daemon or Switch. *)

open Bdsp_engine

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq ~name ~expected ~actual =
  if expected <> actual then fail (Printf.sprintf "%s: mismatch" name)

let plan_json ?(postconditions = "{}") events =
  Printf.sprintf
    {|{"format": "gamepilot-checkpoint/1", "game": "bdsp", "execution": {},
       "metadata": {"phase": "testing", "postconditions": %s},
       "checkpoint": {"id": "01-save-game", "title": "Save Game",
         "events": [%s]}}|}
    postconditions
    (String.concat ", " events)

let decode text =
  Plan_decode.decode ~source:"01-save-game.plan.json"
    (Yojson.Safe.from_string text)

let test_decode_save_game () =
  let text =
    plan_json [ {|{"id": "save", "kind": "save_game", "why": "checkpoint"}|} ]
  in
  match decode text with
  | Error e -> fail ("decode save_game: " ^ e)
  | Ok plan -> (
      assert_eq ~name:"checkpoint id" ~expected:"01-save-game"
        ~actual:plan.checkpoint.checkpoint_id;
      assert_eq ~name:"action text" ~expected:"save_game"
        ~actual:(Bdsp_rules.Action.to_string Save_game);
      match plan.checkpoint.events with
      | [ ev ] ->
          assert_eq ~name:"event id" ~expected:"save" ~actual:ev.id;
          assert_eq ~name:"event kind"
            ~expected:(Plan.Game Bdsp_rules.Action.Save_game) ~actual:ev.kind
      | _ -> fail "expected exactly 1 event")

let test_reject_unknown_action () =
  let text = plan_json [ {|{"id": "bad", "kind": "unknown_kind"}|} ] in
  match decode text with
  | Ok _ -> fail "expected unknown kind to fail"
  | Error _ -> ()

let test_reject_unknown_save_game_args () =
  let text =
    plan_json [ {|{"id": "save", "kind": "save_game", "args": {"extra": 1}}|} ]
  in
  match decode text with
  | Ok _ -> fail "expected unknown args to fail"
  | Error _ -> ()

let test_reject_unknown_postcondition () =
  let text = plan_json ~postconditions:{|{"party": []}|} [] in
  match decode text with
  | Ok _ -> fail "expected unknown postcondition to fail"
  | Error _ -> ()

let test_runner_dispatches_save_game () =
  let text = plan_json [ {|{"id": "save", "kind": "save_game"}|} ] in
  let plan = Result.get_ok (decode text) in
  let seen = ref [] in
  let game : Game.t =
    {
      run_own =
        (fun _ action ->
          seen := action :: !seen;
          Ok ());
      run_builtin = (fun _ -> Ok ());
      game_actions = [];
      flag_holds = (fun _ -> false);
      position = (fun () -> None);
      between_rounds = (fun () -> Ok ());
      save = (fun () -> Ok ());
      reload = (fun () -> Ok ());
      log = ignore;
    }
  in
  match Runner.run game plan.checkpoint with
  | Error f -> fail ("runner failed: " ^ Failure.to_string f)
  | Ok () ->
      assert_eq ~name:"dispatched actions"
        ~expected:[ Bdsp_rules.Action.Save_game ]
        ~actual:!seen

let test_event_snapshot_roundtrip () =
  let kept : Saved.t =
    { at = Some { place = "TwinleafTown"; spot = Some "home" } }
  in
  match Saved.of_yojson (Saved.to_yojson kept) with
  | Ok back -> assert_eq ~name:"snapshot roundtrip" ~expected:kept ~actual:back
  | Error e -> fail ("snapshot roundtrip: " ^ e)

let test_real_underground_plan_decodes () =
  match
    Repo_io.Repo_files.locate
      "src/games/pokemon/bdsp/programs/underground/plans/01-underground-farm.plan.json"
  with
  | None -> fail "could not locate 01-underground-farm.plan.json"
  | Some path -> (
      match Plan_decode.load path with
      | Error e -> fail ("load real plan: " ^ e)
      | Ok plan ->
          assert_eq ~name:"real plan id" ~expected:"01-underground-farm"
            ~actual:plan.checkpoint.checkpoint_id;
          assert_eq ~name:"real plan action text" ~expected:"underground_farm"
            ~actual:(Bdsp_rules.Action.to_string Underground_farm))

let test_real_static_rng_plan_decodes () =
  match
    Repo_io.Repo_files.locate
      "src/games/pokemon/bdsp/programs/static_rng/plans/01-static-rng.plan.json"
  with
  | None -> fail "could not locate 01-static-rng.plan.json"
  | Some path -> (
      match Plan_decode.load path with
      | Error e -> fail ("load real plan: " ^ e)
      | Ok plan ->
          assert_eq ~name:"real plan id" ~expected:"01-static-rng"
            ~actual:plan.checkpoint.checkpoint_id;
          assert_eq ~name:"real plan action text" ~expected:"static_rng"
            ~actual:(Bdsp_rules.Action.to_string Static_rng))

let test_real_battle_catch_plan_decodes () =
  match
    Repo_io.Repo_files.locate
      "src/games/pokemon/bdsp/programs/battle_catch/plans/01-battle-catch.plan.json"
  with
  | None -> fail "could not locate 01-battle-catch.plan.json"
  | Some path -> (
      match Plan_decode.load path with
      | Error e -> fail ("load real plan: " ^ e)
      | Ok plan ->
          assert_eq ~name:"real plan id" ~expected:"01-battle-catch"
            ~actual:plan.checkpoint.checkpoint_id;
          assert_eq ~name:"real plan action text" ~expected:"battle_catch"
            ~actual:(Bdsp_rules.Action.to_string Battle_catch))

let () =
  test_decode_save_game ();
  test_reject_unknown_action ();
  test_reject_unknown_save_game_args ();
  test_reject_unknown_postcondition ();
  test_runner_dispatches_save_game ();
  test_event_snapshot_roundtrip ();
  test_real_underground_plan_decodes ();
  test_real_static_rng_plan_decodes ();
  test_real_battle_catch_plan_decodes ();
  print_endline "test_bdsp_engine: OK"
