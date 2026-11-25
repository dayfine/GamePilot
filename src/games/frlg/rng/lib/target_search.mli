(** The target search: every seed and advance in a range whose static or wild
    Pokemon passes a filter, trying Method 1, 2 and 4.

    Port of [AdvRngFilters], [check_for_match] (both overloads) and the [search]
    of [AdvRngSearcher] and [AdvRngWildSearcher] in the fork's
    [Pokemon/Pokemon_AdvRng.{h,cpp}]. The searchers' mutable state becomes
    arguments; hits come in the C++'s order (seed, then method, then advance). A
    [None] field is the C++'s [Any]. *)

type iv_range = { low : int; high : int }
(** IVs from [low] to [high], both inclusive (0 to 31 accepts any). *)

type iv_ranges = {
  hp : iv_range;
  attack : iv_range;
  defense : iv_range;
  spatk : iv_range;
  spdef : iv_range;
  speed : iv_range;
}
(** One {!iv_range} per stat; a result passes only if every IV is in its range.
*)

type filters = {
  species : string;  (** Wild search only. *)
  level : int;  (** Wild search only. *)
  gender : Pokemon_generation.gender option;
  nature : int option;
  ability : int option;
  ivs : iv_ranges;
  shiny : Pokemon_generation.shiny_type option;
  rng_method : Rng_state.rng_method;
}
(** [AdvRngFilters]. *)

type trainer = { gender_threshold : int; tid_xor_sid : int }
(** The species' gender threshold (C++ default 126) and the trainer's
    [TID xor SID] (default 0). *)

val matches : filters -> trainer -> Pokemon_generation.result -> bool
(** [check_for_match] for a static Pokemon. *)

val matches_wild : filters -> trainer -> Wild_encounter.result -> bool
(** [check_for_match] for a wild one: species and level first. *)

val search_static :
  ?roaming:bool ->
  filters ->
  trainer ->
  seeds:int list ->
  min_advance:int ->
  max_advance:int ->
  Rng_state.t list
(** [AdvRngSearcher::search]: advances from [min_advance] to [max_advance]
    inclusive, for each seed and each method the filter allows. *)

val search_wild :
  filters ->
  trainer ->
  Wild_encounter.slot array ->
  super_rod:bool ->
  seeds:int list ->
  min_advance:int ->
  max_advance:int ->
  Rng_state.t list
(** [AdvRngWildSearcher::search] over one location's slots. *)
