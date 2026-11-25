(** How a log prints a command's step ({!Engine_rules.Command_step}): its name.
*)

val action : Engine_rules.Command_step.t -> string
(** ["soft_reset"]. *)
