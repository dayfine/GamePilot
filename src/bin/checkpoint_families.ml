(* Each family of checkpoint rules (Program_registry.rules) and its library's
   entry points: how gamepilot checkpoints runs its series and how its guide
   lists its checkpoints and the commands that run them. The one place under
   bin/ that picks a family; a program no registry entry names is over the
   Pokémon grid rules. *)

module R = Program_registry

let ( let* ) = Result.bind

type t = {
  run_series : string -> Checkpoints_flags.flags -> (int, string) result;
      (** The series from a plan folder, with the command's flags. *)
  guide : Guide_blocks.rules_guide;
}

let of_rules = function
  | R.Pokemon_grid ->
      { run_series = Checkpoints_command.run_grid; guide = Guide_blocks.grid }

let of_program (p : R.t option) =
  of_rules (match p with Some p -> p.rules | None -> R.Pokemon_grid)

let guide (p : R.t) = (of_program (Some p)).guide

let main plan_dir args =
  let* f = Checkpoints_flags.parse Checkpoints_flags.defaults args in
  (of_program (R.of_plan_dir plan_dir)).run_series plan_dir f
