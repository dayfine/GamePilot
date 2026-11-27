(** After a press, which advance was actually hit: the advances near the one
    aimed at whose starter matches what the summary screen showed (nature,
    gender, shininess, stats). The offset from the aim calibrates the next
    press.

    Port of the fork's
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_RngCalibration.{h,cpp}]
    (https://github.com/dayfine/Arduino-Source), with the two stat formulas it
    calls from [Pokemon/Pokemon_StatsCalculation] (R21: same 16-bit integer
    arithmetic, same order, same messages). Readings that were not taken are
    [None] where the C++ uses -1 or a [*_known] flag. The C++'s observed nature
    is a [NatureCheckerValue], which maps one to one onto the game's nature
    index; this port keeps the index. *)

type adjustment =
  | Neutral
  | Raised
  | Lowered  (** [NatureAdjustment]: [NEUTRAL], [POSITIVE], [NEGATIVE]. *)

val nature_adjustment : nature:int -> stat_index:int -> adjustment
(** [bdsp_nature_adjustment]. [stat_index] orders the stats Attack, Defense,
    Speed, Sp. Atk, Sp. Def (the game's nature table); [Neutral] for an index or
    nature out of range and for the five neutral natures. *)

type 'a per_stat = 'a Static_encounter.per_stat = {
  hp : 'a;
  attack : 'a;
  defense : 'a;
  spatk : 'a;
  spdef : 'a;
  speed : 'a;
}
(** Six values in summary order: [BaseStats] and [StatReads]. *)

val expected_stats :
  Static_encounter.pokemon ->
  base_stats:int per_stat ->
  level:int ->
  int per_stat
(** [bdsp_expected_stats]: the stats a Pokemon with these IVs and nature shows
    at [level] with no EVs. *)

type starter =
  | Turtwig
  | Chimchar
  | Piplup
      (** The three Sinnoh starters, whose stats the hit calibration reads. *)

val starter_base_stats : starter -> int per_stat
(** The starter's base stats, as the C++ lists them. *)

type observed = {
  nature : int option;
  gender : Static_encounter.gender option;
  shiny : bool option;
  stats : int option per_stat;
  base_stats : int per_stat;
  level : int;  (** The C++ default is 5. *)
}
(** [BdspObservedStarter]: what the summary screen showed. *)

val consistent_with : Static_encounter.pokemon -> observed -> bool
(** Every reading that was taken matches the generated Pokemon. *)

type hit = { advance : int; offset : int  (** From the intended advance. *) }
(** The advance the press landed on. *)

type miss = {
  candidates : int;  (** Advances in range that fit the reading: 0 or 2+. *)
  reason : string;  (** The C++'s [failure_reason]. *)
}
(** Why no single advance was found. *)

val identify_hit_advance :
  ?synchronize_nature:int option ->
  Xorshift128.state ->
  Static_encounter.template ->
  intended_advance:int ->
  radius:int ->
  observed ->
  (hit, miss) result
(** [identify_hit_advance ?synchronize_nature state template ~intended_advance
     ~radius observed]: the one advance within [radius] of the intended one (TSV
    0, with [synchronize_nature] defaulting to [None]) whose Pokemon is
    {!consistent_with} the reading. [Error] when none or several are, with the
    C++'s [failure_reason]. *)

val advances_between :
  from:Xorshift128.state ->
  to_:Xorshift128.state ->
  search_max:int ->
  int option
(** How many steps from [from] reach [to_], trying 0 to [search_max]. *)
