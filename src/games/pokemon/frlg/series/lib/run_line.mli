(** FRLG-specific notes added to a checkpoint run's summary line
    (Checkpoint_live_run): a repeating checkpoint's goal and a grind cap. *)

open Pokemon_engine

val goal_note : bool option -> string
(** After a passing round: whether the goal holds now. *)

val capped_note : grind_cap:int option -> Plan.t -> string
(** With --grind-battles: [" (grind capped at N; skipped: ...)"], so a capped
    pass is never taken for a full one. *)
