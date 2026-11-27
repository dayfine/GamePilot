(** Method 1 RNG miss-distance search and calibration delta calculation.

    Port of [get_search_results] and calibration delta logic from
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_RngCalibration.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source). Given an observed
    non-shiny Pokémon's Summary data (nature, gender, level, and optional 6
    stats), searches nearby seed-table rows and RNG advances to find which seed
    and advance actually landed, formats a concise miss report, and computes the
    [(boot_delta_ms, ingame_delta)] correction for the next attempt. *)

(** Observed gender from Summary page 1. *)
type gender =
  | Male  (** Blue male icon observed. *)
  | Female  (** Red/orange female icon observed. *)
  | Genderless  (** No gender icon observed. *)
  | Unknown  (** Gender was not read; matches any gender. *)

type stats = Base_stats.stats = {
  hp : int;  (** Hit Points (max HP). *)
  atk : int;  (** Attack. *)
  def : int;  (** Defense. *)
  spa : int;  (** Special Attack. *)
  spd : int;  (** Special Defense. *)
  spe : int;  (** Speed. *)
}
(** Six observed stats from Summary page 2. *)

type observation = {
  nature : int option;  (** Observed Gen 3 nature index [0..24], if read. *)
  gender : gender;  (** Observed gender, or {!Unknown} if not read. *)
  level : int;  (** Observed level ([2..100]). *)
  stats : stats option;  (** Observed 6 stats from page 2, if read. *)
}
(** Summary observation of a caught or claimed Pokémon. *)

type hit = {
  seed_index : int;  (** Index in [delays]/[seeds] that produced this match. *)
  seed : int;  (** 16-bit initial seed at [seed_index]. *)
  delay_ms : int;  (** Seed-table delay in ms at [seed_index]. *)
  advance : int;  (** Method 1 RNG advance that produced this match. *)
  pid : int32;  (** 32-bit PID generated at [(seed, advance)]. *)
  seed_delta_frames : int;
      (** [seed_index - target_seed_index] (positive = landed later). *)
  delay_delta_ms : int;
      (** [delay_ms - delays.(target_seed_index)] (positive = landed later). *)
  advance_delta : int;
      (** [advance - target_advance] (positive = landed late). *)
}
(** One candidate Method 1 RNG match near the target. *)

val default_seed_radius : int
(** Default seed-table row search radius ([15]). *)

val default_advances_radius : int
(** Default initial advance search radius ([256]). *)

val max_advances_radius : int
(** Maximum advance search radius when doubling after zero hits ([1024]). *)

val find_seed_index :
  delays:int array ->
  seeds:int array ->
  seed:int ->
  table_delay_ms:int ->
  int option
(** Finds the row index in [(delays, seeds)] matching [(seed, table_delay_ms)],
    falling back to the first row with [seeds.(i) = seed]. *)

val search_method1 :
  base_stats:Base_stats.entry ->
  delays:int array ->
  seeds:int array ->
  target_seed_index:int ->
  target_advance:int ->
  ?seed_radius:int ->
  ?advances_radius:int ->
  observation ->
  hit list
(** Searches Method 1 Pokémon in
    [[target_seed_index - seed_radius .. target_seed_index + seed_radius]] and
    [[max 0 (target_advance - adv_radius) .. target_advance + adv_radius]],
    doubling [adv_radius] up to {!max_advances_radius} if 0 hits are found. Hits
    are sorted by [(abs seed_delta_frames * 5) + abs advance_delta]. *)

val format_observation : observation -> string
(** Formats an {!observation} as a single log line (e.g.
    ["Calm Female Lv16 (45/21/29/25/33/23)"]). *)

val format_miss_report :
  target_seed:int ->
  target_delay_ms:int ->
  target_advance:int ->
  hit list ->
  string
(** Single-line summary of the closest miss distance (or no-match notice). *)

val calibration_delta_of_hit : hit -> int * int
(** Returns
    [(boot_delta_ms, ingame_delta) = (-h.delay_delta_ms, -h.advance_delta)]. *)

val damped_calibration_delta : prev_seed_delta:int option -> hit -> int * int
(** Like {!calibration_delta_of_hit}, but when [abs h.seed_delta_frames = 1] and
    [prev_seed_delta] is [Some prev] with [abs prev = 1] in the opposite
    direction (a ±1-frame sign flip), halves [boot_delta_ms]
    ([-(h.delay_delta_ms / 2)]) so the next attempt lands inside the target seed
    window instead of oscillating across its edges. *)
