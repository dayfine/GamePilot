(** What the ["wild_rng"] action does in the game: the hard reset and the blind
    presses that pick the seed and reach the advance, then the catch's summary.

    Ported from the reset and blind sequence for the Sweet Scent target in
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_BlindNavigation.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source; the seed set with A
    and no button held, the save loaded, Sweet Scent used), the same presses and
    waits, as one batch from the reset. The fork's hard reset closes and
    relaunches the game; here it is {!Effects.reset} (mGBA's power switch). The
    fork's shiny check is the shiny sound in battle; GamePilot has no audio, so
    the catch's summary is read instead ({!Frlg_readers.Shiny_star}). *)

val title_presses : Frlg_rng.Rng_timings.t -> Wire.command list
(** From the reset: the title screen's wait, A held 3 s (the seed), the continue
    screen's rest, A (continue) and B (the recap). Shared with {!Gift_rng}. *)

val blind_presses : Frlg_rng.Rng_timings.t -> Wire.command list
(** From the reset: {!title_presses}, then Start, the party, the last member's
    menu and Sweet Scent, its A after the in-game wait. The Sweet Scent user is
    the party's last member, Sweet Scent its menu's second row. *)

val super_rod_presses : Frlg_rng.Rng_timings.t -> Wire.command list
(** From the reset: {!title_presses}, the in-game wait, then Select to cast the
    registered Super Rod facing water. *)

val blind_presses_for :
  Wild_rng_plan.encounter_method -> Frlg_rng.Rng_timings.t -> Wire.command list
(** Selects {!blind_presses} for [Grass] / [Surf] (Sweet Scent) or
    {!super_rod_presses} for [Super_rod]. *)

val find_encounter :
  log:(string -> unit) ->
  ?reset_mode:Rng_reset.mode ->
  ?encounter_method:Wild_rng_plan.encounter_method ->
  Frlg_rng.Rng_timings.t ->
  unit ->
  bool
(** The reset ({!Rng_reset.reset_and_submit}, default {!Rng_reset.Mgba}),
    {!blind_presses_for} [encounter_method] (default [Grass]), optional bite
    confirmation for [Super_rod], and the wild battle's screen within
    {!battle_timeout_ms}. *)

val battle_timeout_ms : int
(** 20 s: how long after the last press the wild battle's screen may take to
    show before the attempt fails. *)

val game_steps :
  log:(string -> unit) ->
  ?reset_mode:Rng_reset.mode ->
  ?show_counters:(Wire.Watch.counter list -> unit) ->
  ?encounter_method:Wild_rng_plan.encounter_method ->
  Frlg_rng.Rng_timings.t ->
  Capture_plan.t ->
  Capture.game_steps
(** {!Capture_steps}' throws and catch, with {!find_encounter} for the
    encounter, and no flee: a foe that is not the target is left in its battle,
    and the next attempt's reset ends it. *)

val legacy_catch :
  log:(string -> unit) ->
  ?show_counters:(Wire.Watch.counter list -> unit) ->
  find_encounter:(unit -> bool) ->
  Capture_plan.t ->
  party:int ->
  Capture.result
(** Runs {!Capture.run} under {!Frlg_battle.Battle_look.probes} with
    [find_encounter] and no flee. Shared by {!Wild_rng} and {!Static_rng}. *)

val policy_catch_for :
  log:(string -> unit) ->
  find_encounter:(unit -> bool) ->
  ?on_miss:(unit -> unit) ->
  catch_mode:Wild_rng_plan.catch_mode ->
  visual_shiny_check:bool ->
  Capture_plan.t ->
  Wild_rng.policy_catch_steps option
(** Selects {!Wild_rng.policy_catch_steps} or [None] (legacy throw-only) from
    [catch_mode] and [visual_shiny_check], using [find_encounter] to start each
    battle. Shared by {!Wild_rng} and {!Static_rng}. *)

val policy_catch_steps :
  log:(string -> unit) ->
  ?reset_mode:Rng_reset.mode ->
  ?encounter_method:Wild_rng_plan.encounter_method ->
  timings:Frlg_rng.Rng_timings.t ->
  ?visual_shiny_check:bool ->
  ?on_miss:(party:int -> unit) ->
  config:Battle_catch_steps.config ->
  policy:Pokemon_catch.Catch_state.policy ->
  unit ->
  Wild_rng.policy_catch_steps
(** Builds {!Wild_rng.policy_catch_steps} combining {!find_encounter}, optional
    {!Frlg_readers.Shiny_encounter_detector.detect}, {!Battle_catch_steps.make}
    with {!Pokemon_catch.Catch_runner.run}, and {!Capture_steps.finish_catch}.
*)

val check_summary :
  log:(string -> unit) ->
  slot:int ->
  read_miss:bool ->
  [ `Shiny | `Not_shiny of Rng_miss_calibration.summary_miss option ]
(** From the overworld: opens [slot]'s Summary Page 1 and checks the shiny star.
    When not shiny and [read_miss] is [true], reads Page 1 (level, species,
    nature, gender), turns to Page 2 to read the 6 stats
    ({!Frlg_text.Summary_stats}), and closes back to the overworld. *)

val shiny_at : log:(string -> unit) -> slot:int -> bool
(** From the overworld: the member's summary, its first page's star read, back
    to the overworld. Fails as [no_party], [no_member_menu] or [no_summary]. *)

val live_calibrated_game_steps :
  log:(string -> unit) ->
  ?reset_mode:Rng_reset.mode ->
  Wild_rng_plan.t ->
  Frlg_rng.Wild_target.t ->
  Wild_rng.game_steps
(** Live {!Wild_rng.game_steps} that recompute {!Wild_rng_plan.target} before
    each subsequent attempt and, on Switch ([plan.frame_model = "switch"]), read
    Summary Page 1 & Page 2 on misses, report the miss distance via
    {!Rng_miss_calibration}, update the in-memory plan offsets for the next
    attempt (with a 10-attempt rolling average via
    {!Frlg_rng.Rolling_calibrator}), persist the timing delta, and skip any
    parity-locked [(seed, advance)] target while resetting the rolling advance
    history. *)
