(** A walk's heading (the fork's [heading], a minimap bearing to face before the
    legs). The fork faces it by the minimap's arrow ([face_heading] in
    PokemonLZA_AutoStoryWalks.cpp, [plza/lean]); no reader here reads the arrow,
    so a walk with one fails loudly instead. *)

val check : string -> float option -> (unit, Engine_run.Failure.cause) result
(** [check walk heading]: [Ok] with no heading; [heading_unread], which repeats,
    with one. *)
