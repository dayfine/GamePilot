(** What [gamepilot run] runs, from its args, and the old
    [gamepilot checkpoints] and [gamepilot checkpoint] forms it replaces, which
    still work: each says its [gamepilot run] form on stderr, then runs it.

    {v
    gamepilot run PROGRAM [flags]          a registry id: one-shot or a chain
    gamepilot run --program PROGRAM [flags]
    gamepilot run PLAN_DIR [flags]         a plan folder no id names
    gamepilot run --plan PLAN.json [flags] one plan file
    v}

    Pure: the caller says which names are plan folders. *)

type target =
  | Program of string  (** A program registry id. *)
  | Plan_folder of string  (** A checkpoint plan folder. *)
  | Plan of string  (** One checkpoint plan file. *)

type t = { target : target; flags : string list }
(** The target and the flags left for its runner, in their order. *)

val parse : is_plan_folder:(string -> bool) -> string list -> (t, string) result
(** [gamepilot run]'s args: [--plan FILE] or [--program ID] anywhere, else the
    first arg, a plan folder when [is_plan_folder] says so and a program id
    otherwise. *)

val of_old_command : string -> string list -> (t, string) result option
(** [gamepilot checkpoints ARGS] ([--program ID] anywhere, else the first arg is
    the plan folder) or [gamepilot checkpoint PLAN ARGS] as [gamepilot run] runs
    it; [None] for any other command. *)

val command_line : t -> string
(** [t] as a [gamepilot run] command line, args quoted where the shell needs it.
*)

val old_command_notice : string -> t -> string
(** The line an old command prints on stderr: its [gamepilot run] form. *)
