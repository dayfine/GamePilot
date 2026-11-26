(** The words of a checkpoint run's summary line (Checkpoint_live_run): which
    run or round it was, its attempt, a repeating checkpoint's goal and a grind
    cap, each a note added to ["PASS 05-grind-mr-mime round 3"]. *)

open Pokemon_engine

val run_name : string -> Plan.t -> int -> string
(** ["05-grind-mr-mime round 3"] for a repeating checkpoint, else
    ["04-grind-farfetchd run 1"]. *)

val attempt_note : Plan.t -> int -> string
(** [" attempt 2/4"] when the plan allows retries. *)

val goal_note : bool option -> string
(** After a passing round: whether the goal holds now. *)

val capped_note : grind_cap:int option -> Plan.t -> string
(** With --grind-battles: [" (grind capped at N; skipped: ...)"], so a capped
    pass is never taken for a full one. *)
