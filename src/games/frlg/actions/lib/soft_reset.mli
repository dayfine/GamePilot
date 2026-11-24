(** Back to the last save without a save state: FireRed's soft reset (A + B +
    SELECT + START; A + B + Minus + Plus on the Switch's Pro Controller), past
    the intro and the title to the load menu, CONTINUE, past the "Previously on
    your quest" recap, to the overworld in control. What the checkpoint runner
    does on the Switch where mGBA loads a save state: before each run and after
    a failure.

    Ported from the fork's [try_soft_reset()] and [soft_reset()]
    (PokemonFRLG_Navigation.cpp, [frlg/lean]) with its timings
    (PokemonFRLG_Settings: SELECT_BUTTON_MASH0 5 s, ENTER_GAME_WAIT0 3 s,
    ENTER_GAME_MASH0 3 s), then the overworld settle of [launch_frlg_save()]
    (AutoStory/PokemonFRLG_AutoStoryLaunch.cpp: its [mash_until_overworld]).

    Where it differs: no random waits (0 to 5 s, twice: they spread an RNG
    program's frames; the story needs none); the fork's A mash stops at a white
    screen ending or the load menu, this one at the load menu alone (no
    white-screen-over reader yet); and an attempt that fails also fails when the
    settle after the recap does not reach a quiet overworld. *)

val combo_hold_ms : int
(** A + B + SELECT + START held 360 ms... *)

val combo_release_ms : int
(** ...then 1440 ms released. *)

val select_mash_ms : int
(** SELECT mashed 5 s after the reset: the intro to the title. *)

val title_mash_ms : int
(** A mashed 1 s at the title... *)

val title_wait_ms : int
(** ...then 5 s for the load menu; the mash and the wait stop when it shows. *)

val menu_settle_ms : int
(** 500 ms for the load menu's animation before CONTINUE. *)

val enter_game_wait_ms : int
(** 3 s for the black screen after CONTINUE to come and go. *)

val recap_mash_ms : int
(** B mashed 3 s over the recap. *)

val attempt : log:(string -> unit) -> unit -> unit
(** One reset, raising {!Menu_input.Action_failed} with [soft_reset_no_menu] (no
    load menu), [soft_reset_not_taken] (the Start menu, a YES/NO or a text box
    showed where the title should: the reset was not taken and START opened the
    menu, which may sit on SAVE; closed with B, never A), [soft_reset_no_game]
    (no black screen after CONTINUE) or the settle's cause. No A is pressed on a
    screen not just read as the title or the load menu. Needs {!probes}
    subscribed. *)

val probes : Wire.probe_spec list
(** The load menu's, the screen facts', the Start menu's and the YES/NO's. *)

val return_to_save :
  log:(string -> unit) -> unit -> (unit, Story.Failure.cause) result
(** Up to {!attempts} resets; [Error] [soft_reset_failed] (repeats) after the
    last. *)
