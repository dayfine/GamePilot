(** A PLZA plan's own keys, checked when it loads so a bad one fails before the
    console moves: every event's [skip_if] flag is one {!Resume_flags} reads. *)

val check : Plza_engine.Plan.t -> (unit, string) result
(** [Error] names the checkpoint, the event and the flag. *)
