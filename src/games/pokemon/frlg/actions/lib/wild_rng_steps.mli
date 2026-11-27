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

val blind_presses : Frlg_rng.Rng_timings.t -> Wire.command list
(** From the reset: the title screen's wait, A held 3 s (the seed), the continue
    screen's rest, A (continue) and B (the recap), then Start, the party, the
    last member's menu and Sweet Scent, its A after the in-game wait. The Sweet
    Scent user is the party's last member, Sweet Scent its menu's second row. *)

val find_encounter :
  log:(string -> unit) -> Frlg_rng.Rng_timings.t -> unit -> bool
(** The reset, {!blind_presses}, and the wild battle's screen within
    {!battle_timeout_ms}. *)

val battle_timeout_ms : int
(** 20 s: how long after the last press the wild battle's screen may take to
    show before the attempt fails. *)

val game_steps :
  log:(string -> unit) ->
  Frlg_rng.Rng_timings.t ->
  Capture_plan.t ->
  Capture.game_steps
(** {!Capture_steps}' throws and catch, with {!find_encounter} for the
    encounter, and no flee: a foe that is not the target is left in its battle,
    and the next attempt's reset ends it. *)

val policy_catch_steps :
  log:(string -> unit) ->
  timings:Frlg_rng.Rng_timings.t ->
  ?visual_shiny_check:bool ->
  ?on_miss:(unit -> unit) ->
  config:Battle_catch_steps.config ->
  policy:Pokemon_catch.Catch_state.policy ->
  unit ->
  Wild_rng.policy_catch_steps
(** Builds {!Wild_rng.policy_catch_steps} combining {!find_encounter}, optional
    {!Frlg_readers.Shiny_encounter_detector.detect}, {!Battle_catch_steps.make}
    with {!Pokemon_catch.Catch_runner.run}, and {!Capture_steps.finish_catch}.
*)

val shiny_at : log:(string -> unit) -> slot:int -> bool
(** From the overworld: the member's summary, its first page's star read, back
    to the overworld. Fails as [no_party], [no_member_menu] or [no_summary]. *)
