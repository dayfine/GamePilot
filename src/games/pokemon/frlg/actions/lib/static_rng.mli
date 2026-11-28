(** The ["static_rng"] game action: timed Method 1 static overworld encounters
    (Zapdos, Articuno, Moltres, Electrode, and similar single-interaction static
    Pokémon), with optional visual battle-intro shiny detection
    ({!Frlg_readers.Shiny_encounter_detector}), Switch rolling auto-calibration
    ({!Rng_calibrated_steps.make}), and Summary {!Frlg_readers.Shiny_star}
    confirmation.

    Ported from the static encounter blind-press sequence in
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_BlindNavigation.cpp] and
    the reset loop in
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_StaticRng.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source): reset, set seed on
    the title screen, load the save, hold the Start menu open for the in-game
    wait so overworld boulders do not add extra RNG advances, close the menu,
    and press A to start the encounter.

    Where it differs: the fork checks for the shiny sound in battle; GamePilot
    has no audio probe, so it either checks visual battle-intro timing
    ({!Frlg_readers.Shiny_encounter_detector}) to skip catching (or run a fast
    throw-only calibration catch on Switch) and reset on a visual miss, or
    catches directly and confirms {!Frlg_readers.Shiny_star} on Summary before
    succeeding. *)

type plan = {
  species : string;  (** The static encounter species, e.g. ["zapdos"]. *)
  tid : int;  (** Trainer ID, 0..65535. *)
  sid : int;  (** Secret ID, 0..65535. *)
  seeds : string;
      (** Seed table filename under [src/games/pokemon/frlg/assets/]. *)
  boot_offset_ms : int;
      (** Console boot timing offset in ms (-10000..10000, default 0). *)
  seed_shift : int;  (** Wrapping 16-bit seed shift (0..65535, default 0). *)
  ingame_offset : int;
      (** Advances added to the in-game wait (-99..99, default 0). *)
  frame_model : string;  (** ["mgba"] or ["switch"]. *)
  min_advance : int;  (** Minimum RNG advance searched. *)
  max_advance : int;  (** Maximum RNG advance searched. *)
  attempts : int;  (** Maximum reset attempts (1..99, default 1). *)
  capture : Capture_plan.t;
      (** Capture target, ball, and ball budget for the encounter. *)
  catch_mode : Wild_rng_plan.catch_mode;
      (** Catch strategy: [Throw_only] by default, or [Catch_policy] for
          {!Battle_catch_steps} Phase 1, Phase 2, or Spore-then-throw catching.
      *)
  visual_shiny_check : bool;
      (** When [true], run {!Frlg_readers.Shiny_encounter_detector} during the
          battle intro to skip full catch turns on visual misses. Defaults to
          [true] on ["switch"] with a policy [catch_mode], [false] otherwise. *)
  cal_ball_row : int;
      (** 0-based row in the Poké Balls pocket thrown during fast non-shiny
          calibration catches on Switch (default [0], overridable via
          [--options cal_ball_row=N]). *)
}
(** Decoded arguments for one ["static_rng"] action. *)

type outcome = {
  end_ : Wild_rng.end_;  (** Final outcome of the static RNG attempt loop. *)
  attempts : int;  (** Number of reset attempts executed. *)
  capture : Capture.result option;
      (** Capture result when a catch completed, else [None]. *)
}
(** Outcome of {!run}. *)

val decode :
  ?options:Run_options.t ->
  ?fallback:Wild_rng_plan.trainer_ids ->
  ?default_frame_model:string ->
  Json_field.obj ->
  (plan, Pokemon_engine.Failure.cause) result
(** Decodes ["species"], optional ["tid"], ["sid"], ["seeds"], ["frame_model"]
    (defaults to [default_frame_model], itself ["mgba"]), ["advances"],
    ["boot_offset_ms"], ["seed_shift"], ["ingame_offset"], ["attempts"],
    ["ball"], ["balls"], ["catch_mode"] (["throw_only"] | ["phase1"] |
    ["phase2"] | ["spore_ball"]), ["visual_shiny_check"], and ["cal_ball_row"].
*)

val apply_calibration : Frlg_rng.Switch_rng_calibration.entry -> plan -> plan
(** Applies a persisted per-console Switch calibration entry to [plan]. *)

val target :
  ?exclude_targets:(int * int) list ->
  plan ->
  (Frlg_rng.Gift_target.t, string) result
(** Reads the seed table and searches for the soonest shiny Method 1 static
    encounter target in [plan.min_advance .. plan.max_advance], timed with
    {!Frlg_rng.Rng_timings.static}. Any [(seed, advance)] pair in
    [exclude_targets] (default [[]]) is skipped. *)

val blind_presses : Frlg_rng.Rng_timings.t -> Wire.command list
(** From the reset: {!Wild_rng_steps.title_presses}, Start to open the menu, the
    remaining in-game wait, B to close the menu, A to talk to the static
    Pokémon, and 1 s of A taps to clear the cry dialogue. *)

val find_encounter :
  log:(string -> unit) ->
  ?reset_mode:Rng_reset.mode ->
  Frlg_rng.Rng_timings.t ->
  unit ->
  bool
(** Hard-resets via {!Rng_reset.reset_and_submit} (default {!Rng_reset.Mgba}),
    submits {!blind_presses}, and waits for
    {!Frlg_readers.Battle_screen.battle_shows} within
    {!Wild_rng_steps.battle_timeout_ms}. *)

val live_game_steps :
  log:(string -> unit) ->
  ?reset_mode:Rng_reset.mode ->
  ?on_miss:(party:int -> unit) ->
  timings:Frlg_rng.Rng_timings.t ->
  plan ->
  Wild_rng.game_steps
(** Builds live {!Wild_rng.game_steps} for [plan] and [timings], pairing
    {!find_encounter} with {!Wild_rng_steps.policy_catch_for} or
    {!Wild_rng_steps.legacy_catch}. *)

val live_calibrated_game_steps :
  log:(string -> unit) ->
  ?reset_mode:Rng_reset.mode ->
  plan ->
  Frlg_rng.Gift_target.t ->
  Wild_rng.game_steps
(** Live {!Wild_rng.game_steps} built via {!Rng_calibrated_steps.make} for
    static Method 1 encounters: recomputes {!target} on subsequent attempts and,
    on Switch ([plan.frame_model = "switch"]), runs fast throw-only catch with
    [cal_ball_row] on visual misses, reads Summary Page 1 & Page 2, calibrates
    via {!Rng_miss_calibration.report_and_calibrate_method1_rolling}, persists
    deltas to {!Frlg_rng.Switch_rng_calibration}, and skips parity-locked
    targets. *)

val run :
  Wild_rng.game_steps -> attempts:int -> Capture_plan.t -> party:int -> outcome
(** Runs up to [attempts] timed static encounter attempts from the overworld
    with [party] members via {!Wild_rng.run}, resetting on visual misses or
    non-shiny catches until a shiny is confirmed on Summary. *)

val failure_code : Wild_rng.end_ -> string option
(** [None] for {!Wild_rng.Shiny}; a short machine code for every failure end. *)

val message : outcome -> string
(** One-line human-readable summary of [outcome]. *)
