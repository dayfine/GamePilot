(** The window of six consecutive LCG states one Pokemon is generated from, at a
    known initial seed and advance.

    Port of [AdvRngState], [AdvRngMethod], [rngstate_from_internal_state],
    [rngstate_from_seed] and [advance_rng_state] in the fork's
    [Pokemon/Pokemon_AdvRng.{h,cpp}]. {!of_seed} jumps with {!Lcg.jump} where
    the C++ steps one by one; the states are the same. *)

type rng_method =
  | Method1
  | Method2
  | Method3
  | Method4
  | Any
      (** [AdvRngMethod]: which of the states after the PID hold the IVs. The
          searches try [Method1], [Method2] and [Method4]; [Method3] and [Any]
          only appear as filters (and [Any] as a searcher's starting method). *)

type t = {
  seed : int;  (** The 16-bit initial seed. *)
  advance : int;
  rng_method : rng_method;
  s0 : int;
  s1 : int;
  s2 : int;
  s3 : int;
  s4 : int;
  s5 : int;
}
(** [AdvRngState]. [advance] counts LCG steps from [seed]: advance [n]'s [s0] is
    the state [n + 1] steps after the seed. [s0] to [s5] are six consecutive
    states: the PID's low half comes from [s0] and its high half from [s1]; the
    IVs come from two of [s2] to [s4], chosen by [rng_method]. *)

val of_internal_state : seed:int -> advance:int -> rng_method -> int -> t
(** [rngstate_from_internal_state]: the window starting at the given state. *)

val of_seed : seed:int -> advance:int -> rng_method -> t
(** [rngstate_from_seed]: the window at [advance] from [seed]. Advance 0 starts
    one step after the seed, as in the C++. *)

val next : t -> t
(** [advance_rng_state]: the window one advance later. *)
