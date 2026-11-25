(** The game's {!Capture.game_steps}, as the fork's ConsoleCaptureActions
    (Programs/AutoStory/PokemonFRLG_AutoStoryCaptureConsole) presses and reads,
    on the battle's {!Frlg_battle.Battle_steps}. The caller subscribes
    {!Frlg_battle.Battle_look.probes} and {!Menu_input.probes}.

    Where it differs:
    - The flee settles the overworld with the talk settle
      ({!Menu_input.settle_back}), not wait_for_quiet_overworld().
    - The species is read off the battle's first message,
      ["Wild SPEAROW appeared!"], drawn in the game's font
      ({!Frlg_text.Line_reading}), not by OCR of the foe's HP box, whose small
      font GamePilot has no glyphs for: only the target's line is a candidate
      (an uncaught target's: the patch's species), so any other species reads as
      unread.
    - New: on the action menu, the foe's caught mark is read
      ({!Frlg_readers.Caught_mark}), and the ball thrown is the plan's. *)

val throw_poll_ms : int
(** 500 ms between looks after a throw; every fourth look with neither answer
    presses B (wait_for_throw()). *)

val throw_timeout_ms : int
(** 60 s for a throw to end. *)

val finish_quiet_ms : int
(** 5 s with no battle screen while B is pressed: the catch's messages, its
    Pokédex page and the nickname question are all behind. *)

val finish_timeout_ms : int
(** 30 s for them, as mash_until_overworld(). *)

val player_down : Effects.measurements -> bool
(** The player's Pokemon fainted: the battle's text box over the foe's HP box,
    the player's HP box gone ("... fainted!", "Use next POKéMON?"). After a
    catch the foe's box is gone too; after a break-free the player's is back. A
    throw that shows it for {!player_down_ms} ends [Player_fainted], before a B
    can answer "Use next POKéMON?" NO and run (mGBA, 2026-11-25, Victory Road:
    the run away read as a catch, the Yes/No box unread). *)

val player_down_ms : int
(** 1 s. *)

val opening_line : string -> string
(** ["Wild SPEAROW appeared!"] for ["spearow"]. *)

val mark_timeout_ms : int
(** 2 s for the caught mark's probes to measure on the action menu; a mark not
    measured in time reads as not caught. *)

val make :
  log:(string -> unit) ->
  spot:Pacing.spot ref ->
  Capture_plan.t ->
  Capture.game_steps
(** A wild battle is found by pacing the plan's [pace] and back from [spot],
    which the steps keep from one search to the next ({!Pacing_steps}). *)
