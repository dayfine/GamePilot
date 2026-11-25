(** What the pre-flight ({!Preflight}) must read of the save to judge its needs:
    the Trainer Card for badges and stars, and the party, held-item marks,
    money, Pokédex count and bag items as postconditions to observe. *)

val reads_card : Need.t list -> bool
(** A need is judged on the Trainer Card's badges or stars: the pre-flight reads
    them. *)

val to_read : Need.t list -> Pokemon_engine.Postconditions.t
(** What {!Postcondition_reads.observe} must read for these needs. *)
