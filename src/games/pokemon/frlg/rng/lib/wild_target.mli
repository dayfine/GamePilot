(** The wild target an RNG attempt aims at: of the shiny Pokémon of one species
    a seed table and an advance range offer, the one reached soonest.

    New: the fork's [PokemonFRLG_WildRng.cpp] takes its seed and advance from
    the user (found with an outside searcher such as Ten Lines) and searches
    only near them to calibrate. Here the program searches the whole table, as
    the user would, with {!Wild_encounter.pokemon_of_state} (Method 1, the wild
    Pokémon's) and {!Pokemon_generation.shiny_type_of_pid}, and times each hit
    with {!Rng_timings.sweet_scent}, keeping the hit whose waits add up least. A
    hit whose timings fail their checks is skipped. *)

type t = {
  seed : int;  (** The initial seed, 16 bits, the title screen press sets. *)
  table_delay_ms : int;  (** the seed table's delay for [seed] *)
  advance : int;
      (** The RNG advance after [seed] that Sweet Scent's encounter lands on. *)
  encounter : Wild_encounter.result;
      (** The wild Pokémon that advance gives: species, level, nature, PID. *)
  timings : Rng_timings.t;  (** The waits that reach [seed] and [advance]. *)
}
(** A seed and advance that give a shiny of the species, and how to reach them.
*)

val total_ms : t -> int
(** The four waits added. *)

val find :
  ?calibrations:Rng_timings.calibrations ->
  ?super_rod:bool ->
  Rng_timings.frame_model ->
  delays:int array ->
  seeds:int array ->
  Wild_encounter.slot array ->
  species:string ->
  tid_xor_sid:int ->
  min_advance:int ->
  max_advance:int ->
  t option
(** Over the rows of one seed column ([seeds.(i)] at [delays.(i)]) and the
    advances [min_advance] to [max_advance] inclusive, timed with [calibrations]
    (default {!Rng_timings.no_calibrations}). Set [super_rod] to [true] when
    [slots] are a 5-slot Super Rod table. *)

val describe : t -> string
(** ["seed BEF4 at 30740 ms, advance 1555: ekans Lv 15, nature 6, PID 26D0850C"].
*)
