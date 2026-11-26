(** [gamepilot run --plan PLAN.json] and
    [gamepilot replay checkpoint WIRELOG PLAN.json]: one FRLG checkpoint plan
    through the checkpoint runner, live in a run folder of its own
    (Attached_run) or replayed from a wire log. *)

type flags = Pokemon_flags.checkpoint_flags = {
  state : string option;
  port : int;
  log_file : string option;
  party : string;
  center : string option;
  walk : bool;
  end_check_only : bool;
  grind_cap : int option;
}
(** The command's flags; a series' runs share them (Pokemon_flags). *)

val usage : string
(** [gamepilot run --plan]'s and [gamepilot replay checkpoint]'s usage lines. *)

val options : flags -> Frlg_checkpoints.Checkpoint_run.options
(** The checkpoint runner's options from the flags, logging to stdout and, with
    --log, to the file. *)

val live :
  program_fields:(string -> (string * string) list) ->
  string ->
  string list ->
  (int, string) result
(** The plan on the daemon at --port, in a run folder of its own; the exit code.
    [program_fields]: run.json's program fields for a plan folder. *)

val replay : string -> string -> string list -> (int, string) result
(** [replay wirelog plan flags]: the plan replayed from the wire log; the exit
    code. *)
