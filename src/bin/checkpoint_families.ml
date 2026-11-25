(* Each family of checkpoint rules (Program_registry.rules) and its library's
   entry points: how gamepilot checkpoints runs its series and how its guide
   lists its checkpoints and the commands that run them. The one place under
   bin/ that picks a family; a program no registry entry names is over the
   Pokémon grid rules. *)

module R = Program_registry
module Plza = Plza_series.Runs
module Plza_flags = Plza_series.Flags

let ( let* ) = Result.bind

type t = {
  run_series : string -> Checkpoints_flags.flags -> (int, string) result;
      (** The series from a plan folder, with the command's flags. *)
  guide : Guide_blocks.rules_guide;
}

let plza_flags plan_dir (f : Checkpoints_flags.flags) ~from_id ~to_id :
    Plza_flags.t =
  {
    from_id;
    to_id;
    runs = f.runs;
    runs_dir = f.runs_dir;
    daemon = f.daemon;
    backend_name = f.backend;
    watch = f.watch;
    daemon_flags = f.daemon_flags;
    program = Attached_run.program_fields (R.of_plan_dir plan_dir);
  }

(* PLZA's checkpoints (Plza_series): the Switch only, testing. *)
let plza_series plan_dir (f : Checkpoints_flags.flags) =
  let* () =
    Plza_flags.takes
      {
        mode = f.mode;
        preflight = f.preflight;
        from_event = f.from_event;
        to_event = f.to_event;
      }
  in
  let* from_id = Checkpoints_flags.required "--from" f.from_id in
  let* to_id = Checkpoints_flags.required "--to" f.to_id in
  let* backend =
    Checkpoints_command.daemon_backend f Engine_run.Checkpoint_trials.Testing
  in
  let* viewport = Checkpoints_command.viewport plan_dir f in
  let* ids = Plan_dir.checkpoint_ids plan_dir in
  let* selected, _ = Plan_dir.select ids ~from_id ~to_id in
  Plza.run_series ~plan_dir
    (plza_flags plan_dir f ~from_id ~to_id)
    ~backend ~viewport selected

let plza_row ~plan_dir id =
  Result.map
    (fun (plan : Plza_checkpoints.Plan.t) ->
      Printf.sprintf "| %s | %s |" plan.checkpoint.checkpoint_id
        (Guide_blocks.cell plan.checkpoint.title))
    (Plza.load_plan ~plan_dir id)

(* PLZA runs through gamepilot checkpoints itself. *)
let plza_commands (_ : R.t) ~args =
  String.concat "\n"
    [
      "# the Switch: each checkpoint once, from where the console is";
      "cd src && opam exec -- dune exec -- gamepilot checkpoints " ^ args
      ^ " --mode testing --backend switch --serial PORT --capture DEVICE \\";
      "    --watch";
    ]

let plza_guide : Guide_blocks.rules_guide =
  {
    rows = (fun ~plan_dir ids -> Guide_blocks.collect (plza_row ~plan_dir) ids);
    commands = plza_commands;
  }

let of_rules = function
  | R.Pokemon_grid ->
      { run_series = Checkpoints_command.run_grid; guide = Guide_blocks.grid }
  | R.Plza_story -> { run_series = plza_series; guide = plza_guide }

let of_program (p : R.t option) =
  of_rules (match p with Some p -> p.rules | None -> R.Pokemon_grid)

let guide (p : R.t) = (of_program (Some p)).guide

let main plan_dir args =
  let* f = Checkpoints_flags.parse Checkpoints_flags.defaults args in
  (of_program (R.of_plan_dir plan_dir)).run_series plan_dir f
