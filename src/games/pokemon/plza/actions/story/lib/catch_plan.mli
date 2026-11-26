(** The decisions of the zone catches that need no screen: which locked-on
    target to choose and whether to step closer, and when the party bar's count
    has settled. Ported from PokemonLZA_AutoStoryCatchPlan.h/.cpp. *)

type target = { x : float; y : float; caught : bool option }
(** A locked-on wild Pokémon: its name plate's bar centre, as fractions of the
    frame, and whether the plate shows the caught mark ([None]: unread). *)

val caught_text : target -> string
(** "caught", "not caught" or "caught mark unread". *)

val step_toward : target -> misses:int -> steps:int -> bool
(** Step closer: nearer Pokémon stand lower on the screen, their plates with
    them (first-throw catches had plates at 0.49 and 0.50; a Mareep missed 11
    times at about 15 m at 0.40). Under 0.45, up to 4 steps before the first
    throw and 2 after a miss. *)

val same : target -> target -> bool
(** Two plates within 0.03 of each other both ways: one target. *)

val nearest_uncaught : target list -> int option
(** The lowest plate not marked caught. *)

type cycle
(** The plates read while flicking right under ZL. *)

val cycle : max_views:int -> cycle
(** None read yet. *)

val add : cycle -> target -> cycle * bool
(** Records the plate; [false] once the cycle is over: a flick found the same
    plate (nothing further that way), it came round to the first, or [max_views]
    are read. *)

val targets : cycle -> target list
(** The plates in the order read. *)

val flicks_to : cycle -> int -> int
(** Flicks from the plate locked now to target [i] (positive: right). *)

val settled_party_slots : (unit -> int option) -> int option
(** Polls [read] (the caller waits 250 ms between looks) until one count holds
    for 13 looks (3 s); [None] if nothing reads in 8 looks (2 s); the last count
    after 32 (8 s). A catch's new member joins the bar seconds after its banner:
    the fork's 03.08 read 4 of 5 slots and failed, and its retry at once read 5
    (console B, 2026-11-18). *)
