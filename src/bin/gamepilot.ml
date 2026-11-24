(* gamepilot run <program> [--port N] [--state PATH]
   gamepilot replay <program> <wirelog>
   gamepilot checkpoint PLAN.json [flags] (Checkpoint_command)
   gamepilot checkpoints PLAN_DIR [flags] (Checkpoints_command)
   gamepilot status [--port N] (Status_command)
   gamepilot runs [--runs-dir DIR] (Runs_command) *)

let usage =
  "usage:\n\
  \  gamepilot run start_menu_poc [--port 47900] [--state PATH]\n\
  \  gamepilot replay start_menu_poc WIRELOG\n" ^ Checkpoint_command.usage
  ^ Checkpoints_command.usage ^ Status_command.usage ^ Runs_command.usage

let die msg =
  prerr_string msg;
  exit 2

let parse_run_flags args =
  let rec go port state = function
    | [] -> (port, state)
    | "--port" :: p :: rest -> (
        match int_of_string_opt p with
        | Some p -> go p state rest
        | None -> die ("bad --port " ^ p ^ "\n" ^ usage))
    | "--state" :: s :: rest -> go port s rest
    | a :: _ -> die ("unknown argument " ^ a ^ "\n" ^ usage)
  in
  go Live.default_port Start_menu_poc.default_state args

(* Runs the program under [handle]; prints the outcome line; returns the exit
   code. *)
let run_program handle state =
  match handle (Start_menu_poc.run ~state) with
  | outcome -> (
      print_endline (Start_menu_poc.describe outcome);
      match outcome with Start_menu_poc.Passed _ -> 0 | _ -> 1)
  | exception Replay.Divergence e ->
      print_endline ("start_menu_poc: DIVERGED " ^ e);
      1
  | exception Effects.Disconnected e ->
      print_endline ("start_menu_poc: DISCONNECTED " ^ e);
      1
  | exception Effects.Rpc_error { code; message; _ } ->
      Printf.printf "start_menu_poc: DAEMON ERROR %d %s\n" code message;
      1
  | exception Unix.Unix_error (e, f, _) ->
      Printf.printf "start_menu_poc: CONNECT FAILED %s: %s\n" f
        (Unix.error_message e);
      1

let exit_with = function
  | Ok code -> exit code
  | Error e -> die (e ^ "\n" ^ usage)

let () =
  match List.tl (Array.to_list Sys.argv) with
  | "run" :: "start_menu_poc" :: flags ->
      let port, state = parse_run_flags flags in
      exit (run_program (Live.run ~port) state)
  | "checkpoint" :: plan :: flags ->
      exit_with (Checkpoint_command.live plan flags)
  | "status" :: flags -> exit_with (Status_command.main flags)
  | "runs" :: flags -> exit_with (Runs_command.main flags)
  | "checkpoints" :: plan_dir :: flags ->
      exit_with (Checkpoints_command.main plan_dir flags)
  | "replay" :: "checkpoint" :: wirelog :: plan :: flags ->
      exit_with (Checkpoint_command.replay wirelog plan flags)
  | [ "replay"; "start_menu_poc"; wirelog ] ->
      let log = Replay.log_of_file wirelog in
      exit (run_program (Replay.run log) Start_menu_poc.default_state)
  | _ -> die usage
