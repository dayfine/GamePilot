type failed = { at : string; reason : string; repeats : bool }

let with_daemon ~failed started body =
  match started with
  | Error reason -> failed { at = "daemon"; reason; repeats = true }
  | Ok daemon ->
      Fun.protect
        ~finally:(fun () -> Daemon_process.stop daemon)
        (fun () -> body daemon)

let in_session ~failed ~dir body =
  match Effects.with_run_folder dir body with
  | outcome -> outcome
  | exception Effects.Disconnected e ->
      failed { at = "session"; reason = "disconnected: " ^ e; repeats = false }
  | exception Unix.Unix_error (e, f, _) ->
      failed
        {
          at = "session";
          reason = f ^ ": " ^ Unix.error_message e;
          repeats = true;
        }

let finish ~runs_dir (run : Run_record.run) ~summary ending =
  print_endline ("[Run] " ^ run.record.dir ^ ": " ^ summary);
  Run_record.finish ~runs_dir run ~summary ending
