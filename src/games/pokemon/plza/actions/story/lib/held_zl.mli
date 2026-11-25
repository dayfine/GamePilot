(** ZL held from the lock-on to the throw: ported from
    PokemonLZA_AutoStoryCatches.cpp. Each hold is queued before the last one
    ends ({!Story_steps.game_steps.queue}), so ZL is never let go while the
    plates are read, the target is flicked to and stepped toward, and the ball
    is thrown (the throw queues its own ZL first). *)

type t
(** The end of the holds queued so far. *)

val start : Story_steps.game_steps -> t
(** Nothing queued yet: the holds start now. *)

val hold : t -> ms:int -> right_x:float -> left_y:float -> unit
(** ZL held [ms] more, after what is queued, with the right stick at ([right_x],
    0) and the left stick at (0, [left_y]) (forward when positive). *)

val read : t -> Catch_plan.target option
(** 1 s more of ZL queued, then the plate read 0.6 s into it (0.4 s of ZL still
    queued). *)

val wait_for_plate : t -> limit_ms:int -> Catch_plan.target option
(** {!read} until a plate reads or [limit_ms] passed. *)

val flick : t -> float -> Catch_plan.target option
(** The right stick at ([x], 0) for 150 ms (the lock moves to the next target
    that way), then {!read}. *)
