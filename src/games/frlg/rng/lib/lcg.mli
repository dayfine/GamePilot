(** The Gen 3 linear congruential generator FRLG draws every roll from:
    [s' = s * 0x41c64e6d + 0x6073 mod 2^32].

    Port of [increment_internal_rng_state] in the fork's
    [Pokemon/Pokemon_AdvRng.cpp]. {!jump} is new: the C++ steps one by one to
    reach an advance, this composes the step in O(log n) and gives the same
    state.

    A 32-bit state is an OCaml [int] from 0 to 2{^ 32} - 1. *)

val next : int -> int
(** One step. *)

val jump : int -> int -> int
(** [jump state n] is [state] after [n >= 0] steps. *)
