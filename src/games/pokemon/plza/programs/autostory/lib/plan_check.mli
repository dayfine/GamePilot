(** A PLZA plan's own keys, checked when it loads so a bad one fails before the
    console moves: [execution] holds only [start_signature] and [end_signature]
    (decoded as {!Start_signature.decode} decodes them) and
    [reload_when_chained] (a boolean), and every event's [skip_if] flag is one
    {!Resume_flags} reads. *)

val check : Plza_engine.Plan.t -> (unit, string) result
(** [Error] names the checkpoint and the key. *)
