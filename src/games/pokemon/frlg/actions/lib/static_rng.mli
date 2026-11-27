(** The ["static_rng"] game action: timed Method 1 static overworld encounters
    (Zapdos, Articuno, Moltres, Electrode, and similar single-interaction static
    Pokémon), with optional visual battle-intro shiny detection
    ({!Frlg_readers.Shiny_encounter_detector}) and Summary
    {!Frlg_readers.Shiny_star} confirmation.

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
    ({!Frlg_readers.Shiny_encounter_detector}) to skip catching and reset on a
    visual miss, or catches directly and confirms {!Frlg_readers.Shiny_star} on
    Summary before succeeding. *)

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
          {!Battle_catch_steps} Phase 1 / Phase 2 catching. *)
  visual_shiny_check : bool;
      (** When [true], run {!Frlg_readers.Shiny_encounter_detector} during the
          battle intro and reset without throwing balls on a visual miss. *)
}
(** Decoded arguments for one ["static_rng"] action. *)

type game_steps = {
  catch : Capture_plan.t -> party:int -> Capture.result;
      (** Legacy throw-only {!Capture.run} on the static blind steps (used when
          [policy_catch] is [None]). *)
  policy_catch : Wild_rng.policy_catch_steps option;
      (** Optional visual shiny pre-check and {!Pokemon_catch.Catch_runner}
          path. When [Some _], replaces [catch]. *)
  shiny_at : int -> bool;
      (** Checks party slot [slot] (1-based) for the Summary shiny star. *)
  log : string -> unit;  (** Writes a line to the run log. *)
}
(** What {!run} reads and does in the game. *)

(** How {!run} ended. *)
type end_ =
  | Shiny  (** Caught, and its Summary page 1 shows the shiny star. *)
  | Not_shiny  (** Caught, but no shiny star on Summary after all attempts. *)
  | Not_shiny_intro
      (** Visual battle-intro detector classified every attempt as non-shiny;
          catch turns and balls were skipped. *)
  | Catch_paused of string
      (** {!Pokemon_catch.Catch_runner} paused safely for user takeover. *)
  | Capture_ended of Capture.end_  (** Capture ended without catching. *)
  | Party_full
      (** The party already has 6 members, leaving no slot for the catch. *)

type outcome = {
  end_ : end_;  (** Final outcome of the static RNG attempt loop. *)
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
    ["phase2"]), and ["visual_shiny_check"]. *)

val apply_calibration : Frlg_rng.Switch_rng_calibration.entry -> plan -> plan
(** Applies a persisted per-console Switch calibration entry to [plan]. *)

val target : plan -> (Frlg_rng.Gift_target.t, string) result
(** Reads the seed table and searches for the soonest shiny Method 1 static
    encounter target in [plan.min_advance .. plan.max_advance], timed with
    {!Frlg_rng.Rng_timings.static}. *)

val blind_presses : Frlg_rng.Rng_timings.t -> Wire.command list
(** From the reset: {!Wild_rng_steps.title_presses}, Start to open the menu, the
    remaining in-game wait, B to close the menu, A to talk to the static
    Pokémon, and 1 s of A taps to clear the cry dialogue. *)

val find_encounter :
  log:(string -> unit) -> Frlg_rng.Rng_timings.t -> unit -> bool
(** Hard-resets, submits {!blind_presses}, and waits for
    {!Frlg_readers.Battle_screen.battle_shows} within
    {!Wild_rng_steps.battle_timeout_ms}. *)

val live_game_steps :
  log:(string -> unit) ->
  ?on_miss:(unit -> unit) ->
  timings:Frlg_rng.Rng_timings.t ->
  plan ->
  game_steps
(** Builds live {!game_steps} for [plan] and [timings], selecting either
    {!Wild_rng.policy_catch_steps} or legacy {!Capture.run} according to
    [plan.catch_mode] and [plan.visual_shiny_check]. *)

val run : game_steps -> attempts:int -> Capture_plan.t -> party:int -> outcome
(** Runs up to [attempts] timed static encounter attempts from the overworld
    with [party] members, resetting on visual misses or non-shiny catches until
    a shiny is confirmed on Summary. *)

val failure_code : end_ -> string option
(** [None] for {!Shiny}; a short machine code for every failure end. *)

val message : outcome -> string
(** One-line human-readable summary of [outcome]. *)
