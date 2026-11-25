(** Bare numeric literals in library code. A number with a meaning gets a name:
    a [let] whose right-hand side is the literal, a record field (config
    defaults), or an optional argument's default. Literals in patterns are fine.
    Single-digit integers and the floats [0.0], [0.5], [1.0], [2.0], [100.0] are
    exempt. *)

val check : Parsed_source.t -> Finding.t list
(** One finding per bare literal, at its line. *)
