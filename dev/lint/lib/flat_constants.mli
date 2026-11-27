(** Flags library modules with too many top-level numeric constants (R27). Many
    flat numeric [let] bindings should be grouped into typed records. *)

val check : Config.t -> Parsed_source.t -> Finding.t list
(** Counts top-level [let] bindings whose right-hand side is a numeric literal
    (optionally negated or type-constrained) and reports one finding when the
    count exceeds [Config.t.flat_constants_max]. *)
