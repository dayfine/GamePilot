(* gamepilot run's --options: one KEY=VALUE each, repeatable, collected in the
   order given; the keys are the program's to check (Run_options). *)

let options args () =
  match Run_flags.parse_no_game_flags args with
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
  let parse = Run_flags.parse_no_game_flags in
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
  let check_eq name ~expected actual =
    Table_test.report name
      (if actual = expected then Ok () else Error "value did not match expected")
  in
  let testing_check args =
    Result.bind (parse args) (Run_flags.require_testing_only ~game:"BDSP")
  in
  check_eq "require_testing_only accepts testing flags" ~expected:(Ok ())
    (testing_check [ "--mode"; "testing"; "--backend"; "switch" ]);
  check_eq "require_testing_only rejects verification and preflight"
    ~expected:
      (Error
         "BDSP runs whole checkpoints in testing mode only: no --mode, \
          --preflight")
    (testing_check [ "--mode"; "verification"; "--preflight" ]);
  check_eq "require_switch accepts Switch backend" ~expected:(Ok ())
    (Run_flags.require_switch ~game:"PLZA"
       (Live_run.Daemon_process.Switch
          { serial = None; frames = Replay "run.mp4" }));
  check_eq "require_switch rejects mGBA backend"
    ~expected:(Error "PLZA runs on the Switch only: --backend switch")
    (Run_flags.require_switch ~game:"PLZA"
       (Live_run.Daemon_process.Mgba { port = 47810 }));
  let f =
    Result.get_ok (parse [ "--backend"; "switch"; "--replay"; "run.mp4" ])
  in
  let opts = Result.get_ok (Run_options.check [] []) in
  check_eq "run_info builds Checkpoints info by default"
    ~expected:
      {
        Run_record.kind = Checkpoints;
        program = [ ("game", "bdsp") ];
        from_id = "01";
        to_id = "02";
        backend = "switch";
        options = [];
      }
    (Run_flags.run_info
       ~program:[ ("game", "bdsp") ]
       ~from_id:"01" ~to_id:"02" ~options:opts f);
  Table_test.finish ()
