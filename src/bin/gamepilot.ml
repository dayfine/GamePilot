(* gamepilot run <program> [--port N] [--state PATH | --console]
   gamepilot replay <program> <wirelog>
   gamepilot checkpoint PLAN.json [flags] (Checkpoint_families)
   gamepilot checkpoints PLAN_DIR|--program ID [flags] (Checkpoint_families)
   gamepilot programs (Programs_command)
   gamepilot guide PROGRAM | --write | --check (Guide_command)
   gamepilot status [--port N] (Status_command)
   gamepilot ctl [--port N] [--owner LABEL] COMMAND | run FILE (Ctl_command)
   gamepilot runs [--runs-dir DIR] (Runs_command)
   gamepilot switch-devices [--profile DIR] (Switch_devices)
   gamepilot bring-up [--serial PORT] (--capture DEVICE | --replay VIDEO)
     (Bring_up_command)
   gamepilot console park|resume [--serial PORT] (--capture DEVICE | --replay
     VIDEO) (Console_park_command)

   <program> and --program take a registry id (Program_registry):
   <game>.<program>, or the program part alone while no other game has one;
   a one-shot program's runner is its family's (Checkpoint_families). *)

let usage =
  "usage:\n\
  \  gamepilot run start_menu_poc [--port 47900] [--state PATH | --console] \
   [--runs-dir DIR]\n\
  \  gamepilot replay start_menu_poc WIRELOG\n" ^ Checkpoint_families.usage
  ^ Checkpoints_flags.usage ^ Programs_command.usage ^ Guide_command.usage
  ^ Status_command.usage ^ Ctl_command.usage ^ Runs_command.usage
  ^ Switch_devices.usage ^ Bring_up_command.usage ^ Console_park_command.usage

let die msg =
  prerr_string msg;
  exit 2

let parse_run_flags (p : Checkpoint_families.one_shot) args =
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
  go Live.default_port (Some p.default_state) args

(* The program under [handle], [after] whether it passed, in the session; the
   outcome's line and exit code. *)
let program_outcome ?(after = ignore) (p : Checkpoint_families.one_shot) handle
    state =
  let run () =
    let report = Watch_report.create ~checkpoint:p.label [ "run" ] in
    Watch_report.start_run report ~mode:"run";
    let passed, line =
      Watch_report.step report "run" (fun () -> p.run ~state)
    in
    if not passed then Watch_report.set report 0 Wire.Watch.Failed line;
    Watch_report.log ignore line;
    Watch_report.end_run report ~passed;
    after passed;
    (passed, line)
  in
  match handle run with
  | passed, line -> (line, if passed then 0 else 1)
  | exception Replay.Divergence e -> (p.label ^ ": DIVERGED " ^ e, 1)
  | exception Effects.Disconnected e -> (p.label ^ ": DISCONNECTED " ^ e, 1)
  | exception Effects.Rpc_error { code; message; _ } ->
      (Printf.sprintf "%s: DAEMON ERROR %d %s" p.label code message, 1)
  | exception Unix.Unix_error (e, f, _) ->
      ( Printf.sprintf "%s: CONNECT FAILED %s: %s" p.label f
          (Unix.error_message e),
        1 )

(* Prints the outcome line; returns the exit code. *)
let run_program p handle state =
  let line, code = program_outcome p handle state in
  print_endline line;
  code

(* Live, in a run folder of its own (Attached_run). *)
let run_live (p : Program_registry.t) one_shot ~runs_dir ~port state =
  let run =
    Attached_run.start ~runs_dir ~kind:Program
      ~program:(Program_registry.run_fields p)
      ~label:p.id ~mode:"run"
  in
  let after passed = if not passed then Attached_run.save_failure run.record in
  let line, code =
    Effects.with_run_folder run.record.dir (fun () ->
        program_outcome ~after one_shot (Live.run ~port) state)
  in
  print_endline line;
  Attached_run.finish ~runs_dir run ~line ~code;
  code

let exit_with = function
  | Ok code -> exit code
  | Error e -> die (e ^ "\n" ^ usage)

(* The one-shot program [id] names, run by [run]. *)
let one_shot id run =
  match Programs_command.one_shot id with
  | Ok p -> (
      match Checkpoint_families.one_shot p with
      | Some one_shot -> run p one_shot
      | None -> die (p.id ^ " has no runner here\n"))
  | Error e -> die (e ^ "\n" ^ usage)

let replay_one_shot wirelog _ (one_shot : Checkpoint_families.one_shot) =
  let log = Replay.log_of_file wirelog in
  exit (run_program one_shot (Replay.run log) (Some one_shot.default_state))

let () =
  match List.tl (Array.to_list Sys.argv) with
  | "run" :: id :: flags ->
      one_shot id (fun p one_shot ->
          match Attached_run.runs_dir_flag flags with
          | Error e -> die (e ^ "\n" ^ usage)
          | Ok (runs_dir, flags) ->
              let port, state = parse_run_flags one_shot flags in
              exit (run_live p one_shot ~runs_dir ~port state))
  | "checkpoint" :: plan :: flags ->
      exit_with (Checkpoint_families.checkpoint plan flags)
  | "status" :: flags -> exit_with (Status_command.main flags)
  | "ctl" :: args -> exit_with (Ctl_command.main args)
  | "runs" :: flags -> exit_with (Runs_command.main flags)
  | "switch-devices" :: flags -> exit_with (Switch_devices.main flags)
  | "bring-up" :: flags -> exit_with (Bring_up_command.main flags)
  | "console" :: args -> exit_with (Console_park_command.main args)
  | "programs" :: flags -> exit_with (Programs_command.main flags)
  | "guide" :: args -> exit_with (Guide_command.main args)
  | "checkpoints" :: args ->
      exit_with
        (Result.bind (Programs_command.plan_dir_of_args args)
           (fun (plan_dir, flags) -> Checkpoint_families.main plan_dir flags))
  | "replay" :: "checkpoint" :: wirelog :: plan :: flags ->
      exit_with (Checkpoint_families.replay_checkpoint wirelog plan flags)
  | [ "replay"; id; wirelog ] -> one_shot id (replay_one_shot wirelog)
  | _ -> die usage
