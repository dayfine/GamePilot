(** The ["wild_rng"] game action's plan: the shiny wild Pokémon to aim at, the
    trainer's IDs, the seed table and frame model to time it with, and the
    catch. The options of
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_WildRng.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source; the target, location,
    species, trainer IDs, seed table and advances) as plan args; the seed and
    advance are searched for ({!Frlg_rng.Wild_target}) instead of given.
    Supports ["grass"] (Sweet Scent in grass), ["surf"] (Sweet Scent on water),
    and ["super_rod"] (registered Super Rod on shore) encounter methods, with
    the game's sound on Mono and its button mode on Help (the seed column
    ["Mono / Help / A"]). *)

(** How {!Wild_rng} triggers a wild encounter after the RNG reset. *)
type encounter_method =
  | Grass  (** Sweet Scent in tall grass or indoor encounter floors. *)
  | Surf  (** Sweet Scent while surfing on water. *)
  | Super_rod  (** Registered Super Rod ([Select]) facing water + bite A. *)

(** How {!Wild_rng} catches a wild encounter once it begins. *)
type catch_mode =
  | Throw_only
      (** Existing throw-only capture loop ({!Capture.run}), default for
          backward compatibility with mGBA plans. *)
  | Catch_policy of {
      policy : Pokemon_catch.Catch_state.policy;
          (** Catching strategy executed by {!Pokemon_catch.Catch_runner.run}.
          *)
      config : Battle_catch_steps.config;
          (** FRLG battle adapter configuration ({!Battle_catch_steps.make}). *)
    }
      (** Structured weakening + status + ball-throw catch via
          {!Battle_catch_steps} and {!Pokemon_catch.Catch_runner}. *)

type t = {
  encounter_method : encounter_method;
      (** How the encounter is triggered and which encounter table is searched
          (default {!Grass}). *)
  species : string;  (** The species to catch shiny: ["ekans"]. *)
  location : string;  (** The encounter table's key: ["route_10"]. *)
  tid : int;
      (** The trainer ID: the public number on the trainer card, 0..65535. *)
  sid : int;
      (** The secret ID: the trainer's hidden second number, 0..65535; with
          [tid] it decides which PIDs are shiny. *)
  seeds : string;
      (** The seed table, a file under [src/games/pokemon/frlg/assets/] in
          FR_Eng.json's shape, measured on one save. *)
  boot_offset_ms : int;
      (** Console boot timing offset in ms applied on top of the frame model's
          fixed seed offset (from {!Frlg_rng.Switch_rng_calibration} on Switch,
          0 by default). *)
  seed_shift : int;
      (** What the save the reset boots from adds to every seed of [seeds]
          (16-bit, wrapping), measured: on mGBA a FireRed save boots a few timer
          counts later or sooner by where its last save left the flash sectors
          (0, 4, 8 or 12 on the Sevii saves), so one table serves every save
          with its offset. 0 when not given. *)
  ingame_offset : int;
      (** Advances added to the in-game wait (the fork's in-game calibration),
          measured: on mGBA a target can land one advance late, by how its waits
          round to frames. 0 when not given. *)
  frame_model : string;  (** ["mgba"] or ["switch"] (Frlg_rng.Rng_timings). *)
  min_advance : int;
      (** The first RNG advance the search tries: fewer cannot be reached in
          time after the continue screen. *)
  max_advance : int;  (** The last RNG advance the search tries. *)
  capture : Capture_plan.t;
      (** The species, the ball, the balls; its encounters are the attempts. *)
  catch_mode : catch_mode;
      (** Catch strategy: [Throw_only] by default, or [Catch_policy] for
          {!Battle_catch_steps} Phase 1, Phase 2, or Spore-then-throw catching.
      *)
  visual_shiny_check : bool;
      (** When [true], run {!Frlg_readers.Shiny_encounter_detector} during the
          wild battle intro to skip catch turns and balls on visual misses.
          Defaults to [true] when [frame_model = "switch"] and
          [catch_mode <> Throw_only], [false] otherwise. *)
  cal_ball_row : int;
      (** 0-based row in the Poké Balls pocket thrown during fast non-shiny
          calibration catches (default [0]; e.g. [1] for Master Ball on row 1).
      *)
}
(** Decoded arguments for one ["wild_rng"] action. *)

type trainer_ids = {
  tid : int option;
      (** Trainer ID from the environment or local config, 0..65535. *)
  sid : int option;
      (** Secret ID from the environment or local config, 0..65535. *)
}
(** Fallback trainer IDs used when neither [--options] nor the plan supplies
    [tid] or [sid]. *)

val no_trainer_ids : trainer_ids
(** No fallback trainer IDs. *)

val encounter_method_to_string : encounter_method -> string
(** ["grass"], ["surf"], or ["super_rod"]. *)

val default_seeds : string
(** Default mGBA seed table filename when ["seeds"] is omitted from a plan. *)

val default_seeds_for_model : string -> string
(** Default seed table filename for a frame model:
    ["rng_seeds_switch_fr_eng.json"] for ["switch"], {!default_seeds} otherwise.
*)

val default_frame_model : string
(** Default frame model (["mgba"]) when ["frame_model"] is omitted. *)

val frame_model_for_backend : string -> string
(** Default frame model for a daemon backend kind: ["switch"] for ["switch"],
    {!default_frame_model} otherwise. *)

val max_id : int
(** Maximum valid 16-bit trainer ID, secret ID, or seed shift ([65535]). *)

val seed_mask : int
(** Bitmask for wrapping 16-bit seeds and seed shifts ([0xffff]). *)

val default_attempts : int
(** Default number of RNG reset attempts when ["attempts"] is omitted ([1]). *)

val max_attempts : int
(** Maximum allowed number of RNG reset attempts ([99]). *)

val max_ingame_offset : int
(** Maximum absolute value allowed for ["ingame_offset"] ([99]). *)

val opt_int :
  where:string ->
  default:int ->
  low:int ->
  high:int ->
  string ->
  Json_field.obj ->
  int
(** Reads an optional integer field in [low..high], returning [default] when
    absent or raising via {!Json_field.fail} on out-of-range / non-int values.
*)

val resolved_id :
  where:string ->
  options:Run_options.t ->
  fallback:int option ->
  string ->
  Json_field.obj ->
  int
(** Resolves a trainer or secret ID from [--options], then [args], then
    [fallback], failing via {!Json_field.fail} if missing or outside
    [0..max_id]. *)

val resolved_attempts :
  where:string -> options:Run_options.t -> Json_field.obj -> int
(** Resolves the reset attempt count from [--options attempts=N], then
    ["attempts"] in [args], defaulting to {!default_attempts}
    ([1..max_attempts]). *)

val advances : where:string -> Json_field.obj -> int * int
(** Reads optional ["advances"] as [[min, max]] with [0 <= min <= max],
    defaulting to [(900, 4000)]. *)

val frame_model : ?default:string -> where:string -> Json_field.obj -> string
(** Reads optional ["frame_model"] (["mgba"] or ["switch"]), defaulting to
    [default] (itself {!default_frame_model}). *)

val find_frame_model : string -> Frlg_rng.Rng_timings.frame_model option
(** Looks up a frame model by name (["mgba"] or ["switch"]). *)

val seed_column_of :
  seeds:string -> seed_shift:int -> (int array * int array, string) result
(** Reads the ["Mono / Help / A"] column from [seeds] under
    [src/games/pokemon/frlg/assets/], shifting every seed by [seed_shift]
    (wrapping 16-bit). *)

val calibrated_model :
  boot_offset_ms:int ->
  ingame_offset:int ->
  Frlg_rng.Rng_timings.frame_model ->
  Frlg_rng.Rng_timings.frame_model * Frlg_rng.Rng_timings.calibrations
(** Applies [boot_offset_ms] directly to [model.fixed_seed_offset_ms] for
    millisecond-accurate seed stepping and builds
    {!Frlg_rng.Rng_timings.calibrations} with [ingame_offset] (splitting odd
    Switch parity into [csf_offset]). *)

val calibrations_of_offsets :
  boot_offset_ms:int ->
  ingame_offset:int ->
  Frlg_rng.Rng_timings.frame_model ->
  Frlg_rng.Rng_timings.calibrations
(** Builds {!Frlg_rng.Rng_timings.calibrations} from boot and in-game offsets.
*)

val default_catch_config : Battle_catch_steps.config
(** Default {!Battle_catch_steps.config} (active slot 1, bag rows 0, 30 s
    timeout). *)

val throw_only_policy : Capture_plan.t -> Pokemon_catch.Catch_state.policy
(** Degenerate {!Pokemon_catch.Catch_state.policy} with no status setter, False
    Swiper, or wall: throws [capture.ball] directly up to [capture.max_balls].
*)

val catch_mode :
  where:string ->
  ?options:Run_options.t ->
  Capture_plan.t ->
  Json_field.obj ->
  catch_mode
(** Reads optional ["catch_mode"] (["throw_only"] | ["phase1"] | ["phase2"] |
    ["spore_ball"], default ["throw_only"]), overridable via [--options]. *)

val visual_shiny_check :
  where:string ->
  ?frame_model:string ->
  ?catch_mode:catch_mode ->
  Json_field.obj ->
  bool
(** Reads optional boolean ["visual_shiny_check"] (defaults to [true] when
    [frame_model = "switch"] and [catch_mode <> Throw_only], [false] otherwise).
*)

val load_trainer_ids : unit -> (trainer_ids, string) result
(** Reads fallback trainer IDs from [GAMEPILOT_FRLG_TID] / [GAMEPILOT_FRLG_SID],
    falling back to [trainer_ids.json] inside the FRLG config directory
    ([Repo_io.Repo_files.data_dir "GAMEPILOT_FRLG_CONFIG" "frlg"]). Missing
    files or unset variables yield [None]; malformed values return [Error]. *)

val apply_calibration : Frlg_rng.Switch_rng_calibration.entry -> t -> t
(** Applies a persisted per-console Switch calibration entry to [t], combining
    [boot_offset_ms], [seed_shift] (wrapping 16-bit), and [ingame_offset]. *)

val apply_timing_delta : boot_delta_ms:int -> ingame_delta:int -> t -> t
(** Adds [boot_delta_ms] to [t.boot_offset_ms] and [ingame_delta] to
    [t.ingame_offset]. *)

val decode :
  ?options:Run_options.t ->
  ?fallback:trainer_ids ->
  ?default_frame_model:string ->
  Json_field.obj ->
  (t, Pokemon_engine.Failure.cause) result
(** ["method"] (["grass"] | ["surf"] | ["super_rod"], default ["grass"]),
    ["species"], ["location"] (["route_10"]), ["tid"], ["sid"] (0..65535, from
    [--options], else the plan, else [fallback]), ["seeds"], ["seed_shift"]
    (0..65535, default 0), ["ingame_offset"] (-99..99, default 0),
    ["frame_model"] (defaults to [default_frame_model], itself ["mgba"]),
    ["advances"] ([[min, max]], default [[900, 4000]]), ["ball"]
    (["poke-ball"]), ["balls"] (5), ["attempts"] (1), ["catch_mode"]
    (["throw_only"] | ["phase1"] | ["phase2"] | ["spore_ball"], default
    ["throw_only"]), ["visual_shiny_check"] (defaults to [true] on ["switch"]
    with a policy [catch_mode], [false] otherwise), ["cal_ball_row"] (0..20,
    default [0], overridable via [--options cal_ball_row=N]). *)

val encounter_slots : string
(** The file the encounter slots are read from, FireRed's:
    [src/games/pokemon/frlg/assets/encounter_slots_firered.json], which
    [src/games/pokemon/frlg/assets/extract/extract_frlg_encounter_slots.py]
    writes from Packages' [EncounterSlotsFR.json] (LeafGreen's beside it). *)

val slots : t -> (Frlg_rng.Wild_encounter.slot array, string) result
(** Loads the encounter slots for [t.location] and [t.encounter_method] from
    {!encounter_slots}. *)

val target :
  ?exclude_targets:(int * int) list ->
  t ->
  (Frlg_rng.Wild_target.t, string) result
(** Reads the seed table and the slots, and searches them: the soonest shiny
    [species] in the advance range, timed for the frame model. Any
    [(seed, advance)] pair in [exclude_targets] (default [[]]) is skipped. *)
