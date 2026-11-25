(** How long a walk's last leg has been held, ported from
    [PokemonLZA_AutoStoryWalks.cpp]. The leg is a time budget for its end, not a
    distance: overshoot is harmless, and falls and fades take game time. A run
    slice takes less time on a console than its length (the inputs run it
    faster), so the leg is held until its time has passed on the screen reads'
    clock too. A clock that stops (a script's repeated last read) leaves the
    slices' lengths to end it. *)

type t
(** The hold so far. *)

val start : int -> t
(** A hold with a budget of that many ms. *)

val unfinished : t -> bool
(** Whether the leg is still to be held. *)

val sliced_ms : t -> int
(** The slices' lengths: the logs' and [earliest_end_ms]'s time. *)

val elapsed_ms : t -> int
(** By the screen reads' clock, from the first slice; at least the budget once
    done. *)

val add_slice : t -> int -> read_at:float -> t
(** The hold after one more slice of that many ms, its screen read at [read_at].
*)
