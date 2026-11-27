(* Typed tests for Series_daemons.close_game_action: --close-game runs only
   after a passing Switch series so failed runs preserve console state. *)

let switch_backend =
  Daemon_process.Switch
    { serial = Some "/dev/ttyUSB0"; frames = Capture "/dev/video0" }

let mgba_backend = Daemon_process.Mgba { port = 47810 }

let show_action = function
  | Series_daemons.Close_game -> "Close_game"
  | Skip_failed_run -> "Skip_failed_run"
  | No_close -> "No_close"

let check name ~close_game ~backend ~passed ~expected =
  let actual = Series_daemons.close_game_action ~close_game ~backend ~passed in
  Table_test.report name
    (if actual = expected then Ok ()
     else
       Error
         (Printf.sprintf "expected %s, got %s" (show_action expected)
            (show_action actual)))

let () =
  check "switch pass with --close-game closes" ~close_game:true
    ~backend:switch_backend ~passed:true ~expected:Series_daemons.Close_game;
  check "switch fail with --close-game skips to preserve console state"
    ~close_game:true ~backend:switch_backend ~passed:false
    ~expected:Series_daemons.Skip_failed_run;
  check "switch pass without --close-game is no-op" ~close_game:false
    ~backend:switch_backend ~passed:true ~expected:Series_daemons.No_close;
  check "switch fail without --close-game is no-op" ~close_game:false
    ~backend:switch_backend ~passed:false ~expected:Series_daemons.No_close;
  check "mgba pass with --close-game is no-op" ~close_game:true
    ~backend:mgba_backend ~passed:true ~expected:Series_daemons.No_close;
  check "mgba fail with --close-game is no-op" ~close_game:true
    ~backend:mgba_backend ~passed:false ~expected:Series_daemons.No_close;
  Table_test.finish ()
