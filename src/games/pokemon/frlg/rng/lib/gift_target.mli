(** The static / gift target an RNG attempt aims at: of the shiny Method 1
    Pokémon a seed table and an advance range offer, the one reached soonest.

    Mirrors {!Wild_target} for Method 1 gift claims (such as Celadon Game Corner
    prizes) that generate directly via {!Pokemon_generation.pokemon_of_state}
    without an encounter-slot roll, timed with {!Rng_timings.gift}. *)

type t = {
  seed : int;  (** The initial seed, 16 bits, the title screen press sets. *)
  table_delay_ms : int;  (** The seed table's delay for [seed]. *)
  advance : int;
      (** The RNG advance after [seed] that the gift confirmation lands on. *)
  pokemon : Pokemon_generation.result;
      (** The Method 1 Pokémon generated at [advance]: nature, IVs, PID. *)
  timings : Rng_timings.t;  (** The waits that reach [seed] and [advance]. *)
}
(** A seed and advance that give a shiny Method 1 gift, and how to reach them.
*)

val total_ms : t -> int
(** The four waits added. *)

val find :
  ?calibrations:Rng_timings.calibrations ->
  ?timing:
    (Rng_timings.frame_model ->
    seed_delay_ms:int ->
    advances:int ->
    use_teachy_tv:bool ->
    Rng_timings.calibrations ->
    (Rng_timings.t, string) result) ->
  ?exclude_targets:(int * int) list ->
  Rng_timings.frame_model ->
  delays:int array ->
  seeds:int array ->
  tid_xor_sid:int ->
  min_advance:int ->
  max_advance:int ->
  t option
(** Over the rows of one seed column ([seeds.(i)] at [delays.(i)]) and the
    advances [min_advance] to [max_advance] inclusive, timed with [timing]
    (default {!Rng_timings.gift}) and [calibrations] (default
    {!Rng_timings.no_calibrations}). Any [(seed, advance)] pair in
    [exclude_targets] (default [[]]) is skipped. *)

val describe : t -> string
(** ["seed BEF4 at 30740 ms, advance 1555: nature 6, PID 26D0850C"]. *)
