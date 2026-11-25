(** A walk event's args, read from a plan with the checks of
    [PokemonLZA_AutoStoryActionTable.cpp] (fork #754), but with the fork's plan
    keys renamed: [held: true] is [style: "steer"] (no [held] is
    ["face_then_walk"]), [wait_ms] is [wait_before_ms] and [end_after_ms] is
    [earliest_end_ms], so a fork plan file needs those keys renamed; [legs] and
    [end] are as the fork writes them. The fields: [legs] (required,
    [[[angle degrees, walk ms], ...]]), [style] (["face_then_walk"], the
    default, or ["steer"]), [wait_before_ms], [end] (["fade_white"],
    ["fade_black"], ["dialog"] or ["scene"]) and [earliest_end_ms] (only with an
    [end]). PLZA's own JSON shape: no other game walks this way yet. Raises
    [Json_field.Invalid] as its readers do; the codec catches it. *)

val walk : where:string -> Json_field.obj -> Plza_rules.Walk_args.t
(** [where] is the prefix of the args' fields
    (["f: checkpoint.events[2].args."]). *)
