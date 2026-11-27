(* gamepilot run <program>|DIR/PLANS|--plan-dir DIR [flags]: a chain of
     checkpoints (Checkpoint_families)
   gamepilot run --plan PLAN.json [flags]: one checkpoint (Checkpoint_families)
   gamepilot replay checkpoint WIRELOG PLAN [flags]
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
   <game>.<program>, or the program part alone while no other game has one. The
   old gamepilot checkpoints and gamepilot checkpoint still work: each prints
   its gamepilot run form on stderr, then runs it (Run_args). *)

let usage =
  "usage:\n" ^ Checkpoint_families.run_usage ^ Checkpoint_families.usage
  ^ "  (gamepilot checkpoints and gamepilot checkpoint: old forms of gamepilot \
     run)\n" ^ Programs_command.usage ^ Guide_command.usage
  ^ Status_command.usage ^ Ctl_command.usage ^ Runs_command.usage
  ^ Switch_devices.usage ^ Bring_up_command.usage ^ Console_park_command.usage
  ^ Setup_command.usage

let die msg =
  prerr_string msg;
  exit 2

let exit_with = function
  | Ok code -> exit code
  | Error e -> die (e ^ "\n" ^ usage)

let run_registered id flags =
  Result.bind (Programs_command.plan_dir id) (fun dir ->
      Checkpoint_families.main dir flags)

(* gamepilot run: what [args] name, expanding [--console ID] if given. *)
let run (args : Run_args.t) =
  Result.bind (Console_config.expand_console_flag args.flags) (fun flags ->
      match args.target with
      | Program id -> run_registered id flags
      | Plan_folder dir -> Checkpoint_families.main dir flags
      | Plan plan -> Checkpoint_families.checkpoint plan flags)

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
  | "run" :: args -> exit_with (Result.bind (Run_args.parse args) run)
  | (("checkpoints" | "checkpoint") as command) :: args -> (
      match Run_args.of_old_command command args with
      | Run parsed -> old_command command (Ok parsed)
      | Invalid_old_args e -> old_command command (Error e)
      | Not_old_command -> die usage)
  | "status" :: flags -> exit_with (Status_command.main flags)
  | "ctl" :: args -> exit_with (Ctl_command.main args)
  | "runs" :: flags -> exit_with (Runs_command.main flags)
  | "switch-devices" :: flags -> exit_with (Switch_devices.main flags)
  | "bring-up" :: flags -> exit_with (Bring_up_command.main flags)
  | "console" :: args -> exit_with (Console_park_command.main args)
  | "setup" :: args -> exit_with (Setup_command.main_setup args)
  | "doctor" :: args -> exit_with (Setup_command.main_doctor args)
  | "programs" :: flags -> exit_with (Programs_command.main flags)
  | "guide" :: args -> exit_with (Guide_command.main args)
  | "replay" :: "checkpoint" :: wirelog :: plan :: flags ->
      exit_with (Checkpoint_families.replay_checkpoint wirelog plan flags)
  | _ -> die usage
