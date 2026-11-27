(* gamepilot run's --options: one KEY=VALUE each, repeatable, collected in the
   order given; the keys are the program's to check (Run_options). *)

let no_game : unit Run_flags.game_flags =
  {
    game_defaults = ();
    game_switch = (fun () _ -> None);
    game_valued = (fun () _ _ -> Run_flags.Not_game_flag);
  }

let options args () =
  match Run_flags.parse no_game (Run_flags.defaults no_game) args with
  | Ok f -> String.concat " " (List.map (fun (k, v) -> k ^ "=" ^ v) f.options)
  | Error e -> "error: " ^ e

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "run_flags"
    [
      case "none" (options []) "";
      case "one"
        (options [ "--options"; "item=master-ball" ])
        "item=master-ball";
      case "repeated, in order, among other flags"
        (options
           [
             "--options";
             "item=master-ball";
             "--from";
             "01";
             "--options";
             "withdraw=50";
           ])
        "item=master-ball withdraw=50";
      case "a value with a comma and an ="
        (options [ "--options"; "name=a,b=c" ])
        "name=a,b=c";
      case "no ="
        (options [ "--options"; "item" ])
        "error: --options item: not KEY=VALUE";
    ];
  let parse args = Run_flags.parse no_game (Run_flags.defaults no_game) args in
  let check_bool name ~expected actual =
    Table_test.report name
      (if actual = expected then Ok ()
       else Error (Printf.sprintf "expected %b, got %b" expected actual))
  in
  let check_backend name ~expected args =
    let actual =
      Result.bind (parse args) (fun f ->
          Run_flags.daemon_backend f Engine_run.Checkpoint_trials.Testing)
    in
    Table_test.report name
      (if actual = expected then Ok ()
       else
         let show = function
           | Ok (Live_run.Daemon_process.Mgba { port }) ->
               Printf.sprintf "Ok (Mgba %d)" port
           | Ok (Live_run.Daemon_process.Switch { serial; frames }) ->
               let s = Option.value serial ~default:"none" in
               let fr =
                 match frames with
                 | Capture d -> "Capture " ^ d
                 | Replay v -> "Replay " ^ v
               in
               Printf.sprintf "Ok (Switch serial=%s %s)" s fr
           | Error e -> "Error " ^ e
         in
         Error
           (Printf.sprintf "expected %s, got %s" (show expected) (show actual)))
  in
  check_bool "close-game default is false" ~expected:false
    (match parse [] with Ok f -> f.close_game | Error _ -> true);
  check_bool "close-game flag sets true" ~expected:true
    (match parse [ "--close-game" ] with
    | Ok f -> f.close_game
    | Error _ -> false);
  check_backend "close-game rejected on mgba"
    ~expected:(Error "--close-game needs --backend switch") [ "--close-game" ];
  check_backend "close-game accepted on switch capture"
    ~expected:
      (Ok
         (Live_run.Daemon_process.Switch
            { serial = Some "/dev/ttyUSB0"; frames = Capture "/dev/video0" }))
    [
      "--backend";
      "switch";
      "--serial";
      "/dev/ttyUSB0";
      "--capture";
      "/dev/video0";
      "--close-game";
    ];
  check_backend "close-game accepted on switch replay"
    ~expected:
      (Ok
         (Live_run.Daemon_process.Switch
            { serial = None; frames = Replay "run.mp4" }))
    [ "--backend"; "switch"; "--replay"; "run.mp4"; "--close-game" ];
  Table_test.finish ()
