(** Poses ({!Pokemon_rules.Pose}) as text, in log lines, failures and a plan's
    text. *)

open Pokemon_rules

val grid : Pose.grid -> string
(** ["CeladonCity (48, 12) south"]; alternatives joined by ["|"]. *)

val observed : Pose.observed -> string
(** ["CeladonCity (48, 12) south"], or without the facing when unknown. *)

val declared : Pose.declared -> string
(** A grid pose as {!grid}, a zone as ["zone <place>"]. *)
