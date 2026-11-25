(** Wild encounters: which slot of a location's table a roll picks, the level
    within the slot, and the Pokemon, whose PID is rerolled until it has the
    nature (or, for Unown, the form) the game chose first.

    Port of the wild half of the fork's [Pokemon/Pokemon_AdvRng.{h,cpp}]:
    [AdvEncounterSlot], [AdvWildPokemonResult], [slot_number_from_roll],
    [slot_to_unownform], [reroll_wild_pokemon], [reroll_unown],
    [wild_pokemon_from_state], [base_species_slug] and [species_matches]. The
    slot thresholds are in {!Encounter_rates}. *)

type slot = { species : string; min_level : int; max_level : int }
(** [AdvEncounterSlot]: a species slug (["unown-b"] for a form) and its level
    range. *)

type result = {
  species : string;
  pokemon : Pokemon_generation.result;
  slot : int;
  level : int;
}
(** [AdvWildPokemonResult]. *)

val slot_number_of_roll : roll:int -> size:int -> super_rod:bool -> int
(** The slot a roll from 0 to 99 picks in a table of [size] slots: 12 (grass), 5
    (surfing, Rock Smash, or Super Rod with [super_rod]), 3 (Good Rod), 2 (Old
    Rod); any other size picks slot 0. *)

val unown_form_of_slot : slot -> int option
(** [slot_to_unownform]: the form an Unown slot's slug ends in, [None] for other
    species. *)

val pokemon_of_state : Rng_state.t -> slot array -> super_rod:bool -> result
(** [wild_pokemon_from_state]: slot from [s0], level from [s1], nature from
    [s2], then the PID reroll from [s3] (from [s2] for Unown). *)

val species_matches : observed:string -> candidate:string -> bool
(** Unown forms match the bare ["unown"]; otherwise the slugs are equal. *)
