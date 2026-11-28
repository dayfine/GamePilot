(** Per-console Switch Wild RNG calibration storage and miss-only offset
    refinement.

    GamePilot's own persistence layer (modeled on the per-console calibration
    offsets in
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_RngCalibration.cpp],
    https://github.com/PokemonAutomation/Arduino-Source). Persists one JSON map
    ([switch_rng_calibration.json]) under the local FRLG data directory
    ({!Repo_io.Repo_files.data_dir}) keyed by console ID, and provides pure
    {!refine_offset} math to update [(seed_shift, ingame_offset)] from a
    calibrated RNG miss without saving the game. *)

type entry = {
  boot_offset_ms : int;
      (** Console boot timing offset in ms applied on top of
          {!Rng_timings.switch}'s fixed seed offset (0 when uncalibrated). *)
  seed_shift : int;
      (** 16-bit wrapping offset added to every seed in the seed table
          (0..65535, 0 when uncalibrated). *)
  ingame_offset : int;
      (** In-game advance correction added to {!Rng_timings.calibrations}'s
          [ingame_offset] (0 when uncalibrated). *)
  updated_at : string;
      (** ISO-8601 UTC timestamp of the last calibration update (empty string
          when uncalibrated). *)
}
(** Persisted Switch Wild RNG calibration offsets for one console. *)

type store = (string * entry) list
(** Map from console ID to its persisted {!entry}, sorted by console ID. *)

type miss_observation = {
  target_seed : int;
      (** Expected 16-bit initial seed (0..65535) for the attempt. *)
  observed_seed : int;
      (** Actual 16-bit initial seed (0..65535) matched from the miss. *)
  target_advance : int;  (** Expected RNG advance for the attempt. *)
  observed_advance : int;  (** Actual RNG advance matched from the miss. *)
}
(** Target vs. observed RNG coordinates from one calibration miss. *)

val format_version : int
(** JSON schema version written by {!to_json} and accepted by {!of_json} (1). *)

val default_console_id : string
(** Fallback console identifier (["default"]) when [GAMEPILOT_CONSOLE_ID] is
    unset or blank. *)

val console_id_env : string
(** Environment variable naming the active console (["GAMEPILOT_CONSOLE_ID"]).
*)

val empty_entry : entry
(** Zeroed calibration entry for an uncalibrated console. *)

val current_console_id : unit -> string
(** Active console ID from [GAMEPILOT_CONSOLE_ID], trimmed, defaulting to
    {!default_console_id}. *)

val default_path : unit -> string
(** Default path to [switch_rng_calibration.json] inside
    [Repo_io.Repo_files.data_dir "GAMEPILOT_FRLG_CONFIG" "frlg"]. *)

val to_json : store -> Yojson.Safe.t
(** Encodes a calibration {!store} as versioned JSON. *)

val of_json : Yojson.Safe.t -> (store, string) result
(** Decodes a versioned JSON calibration {!store}. *)

val find : store -> console_id:string -> entry option
(** Looks up [console_id] in [store] (after trimming whitespace). *)

val upsert : store -> console_id:string -> entry -> store
(** Inserts or replaces [console_id] in [store], keeping entries sorted by
    console ID. *)

val refine_offset : ?updated_at:string -> entry -> miss_observation -> entry
(** Refines [seed_shift] and [ingame_offset] from an observed RNG miss:
    - [seed_shift] shifts by [(observed_seed - target_seed)] modulo 65536 so
      future lookups predict the seed the console actually boots into;
    - [ingame_offset] shifts by [(target_advance - observed_advance)] so landing
      late shortens the in-game wait and landing early lengthens it. *)

val refine_timing :
  ?updated_at:string -> entry -> boot_delta_ms:int -> ingame_delta:int -> entry
(** Refines [boot_offset_ms] and [ingame_offset] by adding [boot_delta_ms] and
    [ingame_delta], leaving [seed_shift] unchanged. *)

val to_calibrations : entry -> Rng_timings.calibrations
(** Converts [boot_offset_ms] (rounded to {!Rng_timings.switch} frames) and
    [ingame_offset] into {!Rng_timings.calibrations}. *)

val load : ?path:string -> unit -> (store, string) result
(** Loads the calibration store from [path] (default {!default_path}). Returns
    [Ok []] when the file does not exist. *)

val save : ?path:string -> store -> (unit, string) result
(** Persists [store] to [path] (default {!default_path}), creating parent
    directories if needed. *)

val load_console :
  ?path:string -> ?console_id:string -> unit -> (entry option, string) result
(** Loads a single console's {!entry} (defaulting [console_id] to
    {!current_console_id}). *)

val record_miss :
  ?path:string ->
  ?console_id:string ->
  ?updated_at:string ->
  miss_observation ->
  (entry, string) result
(** Loads [path], refines [console_id]'s entry with {!refine_offset}, persists
    the updated store, and returns the refined {!entry}. *)

val record_timing_miss :
  ?path:string ->
  ?console_id:string ->
  ?updated_at:string ->
  boot_delta_ms:int ->
  ingame_delta:int ->
  unit ->
  (entry, string) result
(** Loads [path], refines [console_id]'s entry with {!refine_timing}, persists
    the updated store, and returns the refined {!entry}. *)
