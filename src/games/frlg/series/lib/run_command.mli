(** [gamepilot run PROGRAM|DIR/PLANS]: the checkpoint dev loop over FRLG's plans
    (the Pokémon grid rules), or its pre-flight. Each checkpoint runs from its
    start state as many times as the mode's policy says, each run with its own
    daemon and run folder (Checkpoint_series), going on only after it passed.
    See the implementation's header for the flags. *)

type program = {
  fields : string -> (string * string) list;
  viewport : (string option, string) result;
}
(** What the registry says of the program: run.json's program fields for a plan
    folder ([] for none), and the Switch daemons' --viewport, the program's,
    which a --viewport given must match (Program_registry.check_viewport). *)

val run_grid :
  program:program -> string -> Pokemon_flags.flags -> (int, string) result
(** The plan folder's pre-flight (--preflight) or its series; the exit code. *)
