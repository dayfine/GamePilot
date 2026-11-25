(** How long a walk's last leg has been held, ported from [LastLegHold]
    ([PokemonLZA_AutoStoryWalks.cpp], fork #754). The leg is a time budget for
    its end, not a distance: overshoot is harmless, and falls and fades take
    game time. A run slice takes less time on a console than its length (the
    inputs run it faster), so the leg is held until its time has passed on the
    looks' clock too. A clock that stops (a script's repeated last look) leaves
    the slices' lengths to end it. *)

type t
(** The hold so far. *)

val start : int -> t
(** A hold with a budget of that many ms. *)

val holding : t -> bool
(** Whether the leg is still to be held. *)

val sliced : t -> int
(** The slices' lengths: the logs' and [end_after_ms]'s time. *)

val elapsed : t -> int
(** By the looks' clock, from the first slice; at least the budget once done. *)

val held_slice : t -> int -> look_at:float -> t
(** The hold after one more slice of that many ms, looked at [look_at]. *)
