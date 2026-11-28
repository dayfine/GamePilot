(* Tests for Bdsp_checkpoint_series: flag validation and checkpoint range
   selection against a temporary plan directory containing a single save_game
   checkpoint plan. *)

open Bdsp_checkpoint_series

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq ~name ~expected ~actual =
  if expected <> actual then fail (Printf.sprintf "%s: mismatch" name)

let with_temp_plan_dir f =
  let dir = Filename.temp_dir "bdsp_series_test_" "" in
  let plan_path = Filename.concat dir "01-save-game.plan.json" in
  let plan_body =
    {|{
  "format": "gamepilot-checkpoint/1",
  "game": "bdsp",
  "execution": {},
  "metadata": {
    "phase": "testing",
    "postconditions": {}
  },
  "checkpoint": {
    "id": "01-save-game",
    "title": "Save Game",
    "events": [
      {"id": "save", "kind": "save_game", "why": "checkpoint save"}
    ]
  }
}|}
  in
  let oc = open_out plan_path in
  output_string oc plan_body;
  close_out oc;
  Fun.protect
    ~finally:(fun () ->
      (try Sys.remove plan_path with Sys_error _ -> ());
      try Sys.rmdir dir with Sys_error _ -> ())
    (fun () -> f dir)

let test_flags_accepts_testing () =
  match
    Run_flags.parse_no_game_flags [ "--mode"; "testing"; "--backend"; "switch" ]
  with
  | Error e -> fail ("parse testing: " ^ e)
  | Ok f -> (
      match Run_flags.require_testing_only ~game:"BDSP" f with
      | Ok () -> ()
      | Error e -> fail ("takes testing: " ^ e))

let test_flags_rejects_verification () =
  match Run_flags.parse_no_game_flags [ "--mode"; "verification" ] with
  | Error e -> fail ("parse verification: " ^ e)
  | Ok f -> (
      match Run_flags.require_testing_only ~game:"BDSP" f with
      | Ok () -> fail "expected verification mode to be rejected"
      | Error _ -> ())

let test_select_range_defaults_to_all dir =
  let f = Result.get_ok (Run_flags.parse_no_game_flags []) in
  match Checkpoint_series.select_range ~plan_dir:dir f with
  | Error e -> fail ("select_range default: " ^ e)
  | Ok sel ->
      assert_eq ~name:"from_id" ~expected:"01-save-game" ~actual:sel.from_id;
      assert_eq ~name:"to_id" ~expected:"01-save-game" ~actual:sel.to_id;
      assert_eq ~name:"selected" ~expected:[ "01-save-game" ]
        ~actual:sel.selected

let test_load_title dir =
  match Checkpoint_series.load_title ~plan_dir:dir "01-save-game" with
  | Error e -> fail ("load_title: " ^ e)
  | Ok (id, title) ->
      assert_eq ~name:"checkpoint_id" ~expected:"01-save-game" ~actual:id;
      assert_eq ~name:"title" ~expected:"Save Game" ~actual:title

let () =
  test_flags_accepts_testing ();
  test_flags_rejects_verification ();
  with_temp_plan_dir (fun dir ->
      test_select_range_defaults_to_all dir;
      test_load_title dir);
  print_endline "test_bdsp_series: OK"
