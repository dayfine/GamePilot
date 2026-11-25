(** A walk event's args, read from a plan as the C++ reads them
    ([PokemonLZA_AutoStoryActionTable.cpp], fork #754): [legs] (required,
    [[[angle degrees, walk ms], ...]]), [style] (["face_then_walk"], the
    default, or ["steer"]), [wait_before_ms], [end] (["fade_white"],
    ["fade_black"], ["dialog"] or ["scene"]) and [earliest_end_ms] (only with an
    [end]). PLZA's own JSON shape: no other game walks this way yet. Raises
    [Json_field.Invalid] as its readers do; the codec catches it. *)

val walk : where:string -> Json_field.obj -> Plza_terms.Walk_args.t
(** [where] is the prefix of the args' fields
    (["f: checkpoint.events[2].args."]). *)
