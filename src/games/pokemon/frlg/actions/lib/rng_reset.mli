(** Hard reset for FireRed RNG attempts on mGBA and Switch.

    On mGBA ({!Mgba}), resets the emulator with {!Effects.reset} and submits the
    blind presses directly.

    On Switch ({!Switch}), ports [rng_reset_and_return_home] and the opening
    resume press of [perform_blind_sequence] from
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_HardReset.cpp] and
    [PokemonFRLG_BlindNavigation.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source): closes FireRed from
    HOME, launches it past user select and the online license check until the
    startup black screen shows, presses HOME to pause the cold-booted game on
    HOME, and then submits [A 80 ms / 0 ms] followed by the blind sequence as
    one timed batch. *)

(** How an RNG attempt resets the game before submitting its timed blind
    presses. *)
type mode =
  | Mgba  (** Emulator hard reset ({!Effects.reset}). *)
  | Switch of {
      picture : Wire.box;
          (** Game picture viewport inside the full 16:9 Switch frame. *)
      tile : Switch.Home_screen.tile_color;
          (** FireRed's HOME tile colour (or {!Switch.Console_park.no_tile}). *)
    }  (** Switch HOME close, cold launch, pause on HOME, and timed resume. *)

val switch_resume_press : Wire.command
(** [A] held 80 ms with 0 ms cooldown: resumes the cold-booted game from Switch
    HOME at the start of the blind sequence ([perform_blind_sequence] in
    [PokemonFRLG_BlindNavigation.cpp]). *)

val reset_and_submit : log:(string -> unit) -> mode -> Wire.command list -> unit
(** Resets the game according to [mode] and submits the timed blind [presses].
    Raises {!Menu_input.Action_failed} (code ["rng_reset_failed"]) if the Switch
    close/launch/HOME sequence fails. *)
