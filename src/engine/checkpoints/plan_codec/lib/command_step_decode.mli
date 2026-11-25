(** How a generated plan writes a command's steps
    ({!Engine_rules.Command_step}): each step's name is its kind, with no args.
    The names are the command's step table, so the decoder is made for them. *)

val of_names :
  string list ->
  (module Action_parts.ACTION_DECODE with type t = Engine_rules.Command_step.t)
(** The decoder that owns these step names. *)
