(* gamepilot run <program> [--port N] [--state PATH | --console]
   gamepilot replay <program> <wirelog>
   gamepilot checkpoint PLAN.json [flags] (Checkpoint_command)
   gamepilot checkpoints PLAN_DIR|--program ID [flags] (Checkpoints_command)
   gamepilot programs (Programs_command)
   gamepilot status [--port N] (Status_command)
   gamepilot runs [--runs-dir DIR] (Runs_command)
   gamepilot switch-devices [--profile DIR] (Switch_devices)

   <program> and --program take a registry id (Program_registry):
   frlg.start_menu_poc, or start_menu_poc while no other game has one. *)

let usage =
  "usage:\n\
  \  gamepilot run start_menu_poc [--port 47900] [--state PATH | --console]\n\
  \  gamepilot replay start_menu_poc WIRELOG\n" ^ Checkpoint_command.usage
  ^ Checkpoints_command.usage ^ Programs_command.usage ^ Status_command.usage
  ^ Runs_command.usage ^ Switch_devices.usage

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
    | "--state" :: s :: rest -> go port (Some s) rest
    | "--console" :: rest -> go port None rest
    | a :: _ -> die ("unknown argument " ^ a ^ "\n" ^ usage)
  in
  go Live.default_port (Some Start_menu_poc.default_state) args

(* Runs the program under [handle]; prints the outcome line; returns the exit
   code. *)
let run_program handle state =
  match handle (Start_menu_poc.run ?state) with
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

(* The one-shot program [id] names, run by [run]. *)
let one_shot id run =
  match Programs_command.one_shot id with
  | Ok { id = "frlg.start_menu_poc"; _ } -> run ()
  | Ok p -> die (p.id ^ " has no runner here\n")
  | Error e -> die (e ^ "\n" ^ usage)

let replay_start_menu wirelog () =
  let log = Replay.log_of_file wirelog in
  exit (run_program (Replay.run log) (Some Start_menu_poc.default_state))

let () =
  match List.tl (Array.to_list Sys.argv) with
  | "run" :: id :: flags ->
      one_shot id (fun () ->
          let port, state = parse_run_flags flags in
          exit (run_program (Live.run ~port) state))
  | "checkpoint" :: plan :: flags ->
      exit_with (Checkpoint_command.live plan flags)
  | "status" :: flags -> exit_with (Status_command.main flags)
  | "runs" :: flags -> exit_with (Runs_command.main flags)
  | "switch-devices" :: flags -> exit_with (Switch_devices.main flags)
  | "programs" :: flags -> exit_with (Programs_command.main flags)
  | "checkpoints" :: args ->
      exit_with
        (Result.bind (Programs_command.plan_dir_of_args args)
           (fun (plan_dir, flags) -> Checkpoints_command.main plan_dir flags))
  | "replay" :: "checkpoint" :: wirelog :: plan :: flags ->
      exit_with (Checkpoint_command.replay wirelog plan flags)
  | [ "replay"; id; wirelog ] -> one_shot id (replay_start_menu wirelog)
  | _ -> die usage
