(* gamepilot run <program>|PLAN_DIR [flags]: a one-shot
     program ([--state PATH | --console], on a daemon up on --port N or, with
     --watch, its own: One_shot_flags) or a chain of checkpoints
     (Checkpoint_families)
   gamepilot run --plan PLAN.json [flags]: one checkpoint (Checkpoint_families)
   gamepilot replay <program> <wirelog>
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

   <program> (or --program) takes a registry id (Program_registry):
   <game>.<program>, or the program part alone while no other game has one;
   a one-shot program's runner is its family's (Checkpoint_families). The old
   gamepilot checkpoints and gamepilot checkpoint still work: each prints its
   gamepilot run form on stderr, then runs it (Run_args). *)

let usage =
  "usage:\n\
  \  gamepilot run frlg.start_menu_poc [--port 47900] [--state PATH | \
   --console] [--runs-dir DIR]\n\
  \  gamepilot run frlg.start_menu_poc --watch [--listen ADDR] [--watch-port \
   N] [--mgba-port N | --backend switch ...] [--daemon PATH] [--state PATH | \
   --console] [--runs-dir DIR]\n\
  \  gamepilot replay frlg.start_menu_poc WIRELOG\n"
  ^ Checkpoint_families.checkpoints_usage ^ Checkpoint_families.usage
  ^ "  (gamepilot checkpoints and gamepilot checkpoint: old forms of gamepilot \
     run)\n" ^ Programs_command.usage ^ Guide_command.usage
  ^ Status_command.usage ^ Ctl_command.usage ^ Runs_command.usage
  ^ Switch_devices.usage ^ Bring_up_command.usage ^ Console_park_command.usage

let die msg =
  prerr_string msg;
  exit 2

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

(* The program in [handle]'s session, its run folder [record]'s. *)
let in_run_folder one_shot (record : Run_record.t) handle state =
  let after passed = if not passed then Attached_run.save_failure record in
  Effects.with_run_folder record.dir (fun () ->
      program_outcome ~after one_shot handle state)

(* In a daemon of its own, stopped after the run (Daemon_run). *)
let on_own_daemon one_shot (f : One_shot_flags.t) own_daemon record =
  let failed (e : Daemon_run.failed) =
    (one_shot.Checkpoint_families.label ^ ": DAEMON FAILED " ^ e.reason, 1)
  in
  let started =
    One_shot_flags.start own_daemon ~runs_dir:f.runs_dir record
      ~label:one_shot.label
  in
  Daemon_run.with_daemon ~failed started (fun daemon ->
      in_run_folder one_shot record (Live.run ~port:daemon.port) f.state)

(* On a daemon already up, or one of its own (One_shot_flags). *)
let on_daemon one_shot (f : One_shot_flags.t) record =
  match f.daemon with
  | Attach port -> in_run_folder one_shot record (Live.run ~port) f.state
  | Start own_daemon -> on_own_daemon one_shot f own_daemon record

let backend_name (f : One_shot_flags.t) =
  match f.daemon with
  | Attach _ -> None
  | Start own_daemon -> Some own_daemon.backend_name

(* Live, in a run folder of its own (Attached_run). *)
let run_live (p : Program_registry.t) one_shot (f : One_shot_flags.t) =
  let run =
    Attached_run.start ?backend:(backend_name f) ~runs_dir:f.runs_dir
      ~kind:Program
      ~program:(Program_registry.run_fields p)
      ~label:p.id ~mode:"run" ()
  in
  let line, code = on_daemon one_shot f run.record in
  print_endline line;
  Attached_run.finish ~runs_dir:f.runs_dir run ~line ~code;
  code

let exit_with = function
  | Ok code -> exit code
  | Error e -> die (e ^ "\n" ^ usage)

(* The one-shot program [p] live, with gamepilot run's flags. *)
let run_one_shot (p : Program_registry.t) flags =
  match Checkpoint_families.one_shot p with
  | None -> Error (p.id ^ " has no runner here")
  | Some one_shot ->
      Result.map (run_live p one_shot)
        (One_shot_flags.parse p ~default_state:one_shot.default_state flags)

let run_registered id flags =
  match Programs_command.runnable id with
  | Error e -> Error e
  | Ok (One_shot p) -> run_one_shot p flags
  | Ok (Chain (_, dir)) -> Checkpoint_families.main dir flags

(* gamepilot run: what [args] name. *)
let run (args : Run_args.t) =
  match args.target with
  | Program id -> run_registered id args.flags
  | Plan_folder dir -> Checkpoint_families.main dir args.flags
  | Plan plan -> Checkpoint_families.checkpoint plan args.flags

let is_plan_folder d = Sys.file_exists d && Sys.is_directory d

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

(* gamepilot checkpoints and gamepilot checkpoint: their gamepilot run form on
   stderr, then that run. *)
let old_command command parsed =
  exit_with
    (Result.bind parsed (fun args ->
         prerr_endline (Run_args.old_command_notice command args);
         run args))

let () =
  match List.tl (Array.to_list Sys.argv) with
  | "run" :: args when List.mem "--help" args ->
      print_string usage;
      exit 0
  | "run" :: args ->
      exit_with (Result.bind (Run_args.parse ~is_plan_folder args) run)
  | (("checkpoints" | "checkpoint") as command) :: args -> (
      match Run_args.of_old_command command args with
      | Some parsed -> old_command command parsed
      | None -> die usage)
  | "status" :: flags -> exit_with (Status_command.main flags)
  | "ctl" :: args -> exit_with (Ctl_command.main args)
  | "runs" :: flags -> exit_with (Runs_command.main flags)
  | "switch-devices" :: flags -> exit_with (Switch_devices.main flags)
  | "bring-up" :: flags -> exit_with (Bring_up_command.main flags)
  | "console" :: args -> exit_with (Console_park_command.main args)
  | "programs" :: flags -> exit_with (Programs_command.main flags)
  | "guide" :: args -> exit_with (Guide_command.main args)
  | "replay" :: "checkpoint" :: wirelog :: plan :: flags ->
      exit_with (Checkpoint_families.replay_checkpoint wirelog plan flags)
  | [ "replay"; id; wirelog ] -> one_shot id (replay_one_shot wirelog)
  | _ -> die usage
