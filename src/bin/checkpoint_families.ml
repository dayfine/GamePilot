(* Each family of checkpoint rules (Program_registry.rules) and its library's
   entry points: how gamepilot checkpoints runs its series, how gamepilot
   checkpoint runs or replays one plan, how its guide lists its checkpoints,
   their needs and the commands that run them, and what gamepilot programs
   says a chain needs. The one place under bin/ that picks a family; a program
   no registry entry names is over the Pokémon grid rules. *)

module R = Program_registry
module Grid = Frlg_series

let ( let* ) = Result.bind

type t = {
  run_series : string -> Checkpoints_flags.flags -> (int, string) result;
      (** The series from a plan folder, with the command's flags. *)
  run_checkpoint : string -> string list -> (int, string) result;
      (** One plan file on a running daemon, with the command's flags. *)
  replay_checkpoint : string -> string -> string list -> (int, string) result;
      (** One plan file replayed from a wire log. *)
  guide : Guide_blocks.rules_guide;
  chain_needs : string -> (string, string) result;
      (** What a plan folder's chain needs of the save, in one line (gamepilot
          programs). *)
}

(* run.json's program fields for a plan folder; none for no program. *)
let program_fields plan_dir =
  Option.fold ~none:[] ~some:R.run_fields (R.of_plan_dir plan_dir)

(* The Switch daemons' --viewport: the program's, which a --viewport given
   must match. *)
let viewport plan_dir (f : Checkpoints_flags.flags) =
  R.check_viewport (R.of_plan_dir plan_dir) f.viewport

let grid_series plan_dir f =
  Grid.Checkpoints_command.run_grid
    ~program:{ fields = program_fields; viewport = viewport plan_dir f }
    plan_dir f

(* The Pokémon grid rules' guide. *)
let grid_guide : Guide_blocks.rules_guide =
  {
    rows = Grid.Guide_tables.rows;
    needs = Grid.Guide_tables.needs;
    preflight = Grid.Guide_tables.preflight;
    commands = Guide_blocks.grid_commands;
  }

(* The Pokémon grid rules' entry points. *)
let grid =
  {
    run_series = grid_series;
    run_checkpoint = Grid.Checkpoint_command.live ~program_fields;
    replay_checkpoint = Grid.Checkpoint_command.replay;
    guide = grid_guide;
    chain_needs = Grid.Chain_needs.needs;
  }

let of_rules = function R.Pokemon_grid -> grid

let of_program (p : R.t option) =
  of_rules (match p with Some p -> p.rules | None -> R.Pokemon_grid)

let guide (p : R.t) = (of_program (Some p)).guide

let main plan_dir args =
  let* f = Checkpoints_flags.parse Checkpoints_flags.defaults args in
  (of_program (R.of_plan_dir plan_dir)).run_series plan_dir f

(* gamepilot checkpoint's usage: the grid rules', the only family that runs a
   plan file alone. *)
let usage = Grid.Checkpoint_command.usage
let of_plan_file plan = of_program (R.of_plan_dir (Filename.dirname plan))
let checkpoint plan args = (of_plan_file plan).run_checkpoint plan args

let replay_checkpoint wirelog plan args =
  (of_plan_file plan).replay_checkpoint wirelog plan args
