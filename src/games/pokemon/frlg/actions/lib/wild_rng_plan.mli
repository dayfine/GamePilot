(** The ["wild_rng"] game action's plan: the shiny wild Pokémon to aim at, the
    trainer's IDs, the seed table and frame model to time it with, and the
    catch. The options of
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_WildRng.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source; the target, location,
    species, trainer IDs, seed table and advances) as plan args; the seed and
    advance are searched for ({!Frlg_rng.Wild_target}) instead of given. Sweet
    Scent targets only, on a grass location, with the game's sound on Mono and
    its button mode on Help (the seed column ["Mono / Help / A"]). *)

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
  species : string;  (** The species to catch shiny: ["ekans"]. *)
  location : string;  (** The grass table's key: ["route_10"]. *)
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
          {!Battle_catch_steps} Phase 1 / Phase 2 catching. *)
  visual_shiny_check : bool;
      (** When [true], run {!Frlg_readers.Shiny_encounter_detector} during the
          wild battle intro to skip catch turns and balls on visual misses. *)
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

val default_catch_config : Battle_catch_steps.config
(** Default {!Battle_catch_steps.config} (active slot 1, bag rows 0, 30 s
    timeout). *)

val throw_only_policy : Capture_plan.t -> Pokemon_catch.Catch_state.policy
(** Degenerate {!Pokemon_catch.Catch_state.policy} with no status setter, False
    Swiper, or wall: throws [capture.ball] directly up to [capture.max_balls].
*)

val load_trainer_ids : unit -> (trainer_ids, string) result
(** Reads fallback trainer IDs from [GAMEPILOT_FRLG_TID] / [GAMEPILOT_FRLG_SID],
    falling back to [trainer_ids.json] inside the FRLG config directory
    ([Repo_io.Repo_files.data_dir "GAMEPILOT_FRLG_CONFIG" "frlg"]). Missing
    files or unset variables yield [None]; malformed values return [Error]. *)

val apply_calibration : Frlg_rng.Switch_rng_calibration.entry -> t -> t
(** Applies a persisted per-console Switch calibration entry to [t], combining
    [boot_offset_ms], [seed_shift] (wrapping 16-bit), and [ingame_offset]. *)

val decode :
  ?options:Run_options.t ->
  ?fallback:trainer_ids ->
  Json_field.obj ->
  (t, Pokemon_engine.Failure.cause) result
(** ["species"], ["location"] (["route_10"]), ["tid"], ["sid"] (0..65535, from
    [--options], else the plan, else [fallback]), ["seeds"], ["seed_shift"]
    (0..65535, default 0), ["ingame_offset"] (-99..99, default 0),
    ["frame_model"] (["mgba"]), ["advances"] ([[min, max]], default
    [[900, 4000]]), ["ball"] (["poke-ball"]), ["balls"] (5), ["attempts"] (1),
    ["catch_mode"] (["throw_only"] | ["phase1"] | ["phase2"], default
    ["throw_only"]), ["visual_shiny_check"] ([false]). *)

val encounter_slots : string
(** The file the grass slots are read from, FireRed's:
    [src/games/pokemon/frlg/assets/encounter_slots_firered.json], which
    [src/games/pokemon/frlg/assets/extract/extract_frlg_encounter_slots.py]
    writes from Packages' [EncounterSlotsFR.json] (LeafGreen's beside it). *)

val target : t -> (Frlg_rng.Wild_target.t, string) result
(** Reads the seed table and the slots, and searches them: the soonest shiny
    [species] in the advance range, timed for the frame model. *)
