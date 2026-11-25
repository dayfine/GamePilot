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
      font GamePilot has no glyphs for: only the target's line is a candidate,
      so any other species reads as unread and is run from. *)

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

val opening_line : string -> string
(** ["Wild SPEAROW appeared!"] for ["spearow"]. *)

val make :
  log:(string -> unit) ->
  pace:Grid_geometry.Direction.t ->
  spot:Pacing.spot ref ->
  target:string ->
  Capture.game_steps
(** A wild battle is found by pacing [pace] and back from [spot], which the
    steps keep from one search to the next ({!Pacing_steps}). [target]: the
    plan's species. *)
