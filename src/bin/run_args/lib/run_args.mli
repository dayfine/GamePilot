(** What [gamepilot run] runs, from its args, and the old
    [gamepilot checkpoints] and [gamepilot checkpoint] forms it replaces, which
    still work: each says its [gamepilot run] form on stderr, then runs it.

    {v
    gamepilot run PROGRAM [flags]          a registry id: one-shot or a chain
    gamepilot run --program PROGRAM [flags]
    gamepilot run DIR/PLANS [flags]        a plan folder: a path with a /
    gamepilot run --plan-dir DIR [flags]   a plan folder, any name
    gamepilot run --plan PLAN.json [flags] one plan file
    v}

    A bare name is always a program id, never a folder that happens to have its
    name. Pure: it reads no files. *)

type target =
  | Program of string  (** A program registry id. *)
  | Plan_folder of string  (** A checkpoint plan folder. *)
  | Plan of string  (** One checkpoint plan file. *)

type t = { target : target; flags : string list }
(** The target and the flags left for its runner, in their order. *)

val parse : string list -> (t, string) result
(** [gamepilot run]'s args: one of [--plan FILE], [--program ID] and
    [--plan-dir DIR] anywhere, else the first arg: a plan folder when it is a
    path (it has a [/], or a backslash on Windows) and a program id otherwise.
*)

(** Result of translating a deprecated command into [gamepilot run] args. *)
type old_command =
  | Not_old_command
      (** The command name is neither [checkpoints] nor [checkpoint]. *)
  | Invalid_old_args of string
      (** Recognized old command, but invalid arguments. *)
  | Run of t  (** Translated [gamepilot run] arguments. *)

val of_old_command : string -> string list -> old_command
(** [gamepilot checkpoints ARGS] ([--program ID] anywhere, else the first arg is
    the plan folder, whatever its name) or [gamepilot checkpoint PLAN ARGS] as
    [gamepilot run] runs it. *)

val command_line : t -> string
(** [t] as a [gamepilot run] command line, args quoted where the shell needs it;
    a plan folder whose name is no path as [--plan-dir DIR]. *)

val old_command_notice : string -> t -> string
(** The line an old command prints on stderr: its [gamepilot run] form. *)
