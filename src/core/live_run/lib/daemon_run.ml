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

let run_live ~failed ~dir ~port body =
  match
    in_session ~failed ~dir (fun () -> Live.run_with_backend ~port body)
  with
  | outcome -> outcome
  | exception e ->
      failed { at = "raised"; reason = Printexc.to_string e; repeats = false }

let finish ~runs_dir (run : Run_record.run) ~summary ending =
  print_endline ("[Run] " ^ run.record.dir ^ ": " ^ summary);
  Run_record.finish ~runs_dir run ~summary ending

let save ~log what op =
  match op () with
  | (_ : int) -> log ("[Run] saved " ^ what)
  | exception Effects.Rpc_error e ->
      log (Printf.sprintf "[Run] could not save %s: %s" what e.message)

let save_op path file : Run_record.save -> unit -> int = function
  | Frame -> fun () -> Effects.save_frame (path file)
  | State -> fun () -> Effects.save_state (path file)

let save_failure ~log record ~save_states =
  let path = Run_record.path record in
  List.iter
    (fun (file, kind) -> save ~log file (save_op path file kind))
    (Run_record.failure_saves ~save_states)
