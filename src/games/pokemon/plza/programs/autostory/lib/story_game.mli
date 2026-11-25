(** PLZA's AutoStory as a game of the checkpoint engine ({!Plza_engine}): the
    handlers 01.00b's and 01.01's plans use, over {!Plza_story.Steps}. The
    fork's action table (PokemonLZA_AutoStoryActionTable.cpp) for these actions:

    - [confirm_new_game] ({!Plza_story.New_game_confirm}), no args;
    - [opening_to_platform] and [wait_for_platform]
      ({!Plza_story.Platform_wait}), with an optional [timeout_ms] (240 s and
      180 s when absent). Where it differs: when [wait_for_platform] sees no
      controls hint, which fades after a few seconds idle (console B,
      2026-11-25: 01.01 started a minute after 01.00b ended), it reloads the
      latest autosave, where the hint shows fresh, and waits again; the fork
      starts 01.01 right after the opening or a reload and never needed it;
    - [set_text_speed_fast] ({!Plza_story.Text_speed}) and [plus_skip]
      ({!Plza_story.Plus_skip}), no args;
    - the engine's [scene] ({!Plza_story.Scene_machine}): its [action]
      ["end_on_black_fade"] for the fork's scene ending on a black fade,
      ["button_b"] for its scene pressing B (B on text and cutscenes, 120 s);
    - the game's [walk] ({!Plza_walk.Walk}), walked rather than run before 03.03
      (as PokemonLZA_AutoStory.cpp walks them, before dash is unlocked).

    Where it differs: only 01.00b's and 01.01's actions so far. The other
    scenes', battles', catches' and the later walks' come in later PRs; a plan
    that names one fails [no_handler].

    PLZA reads no position and no flag, and saves only by autosave: [save]
    fails; [reload] is the caller's (back to the latest autosave). *)

val walk_only : string -> bool
(** Whether a checkpoint's runs are walked: its id is before ["03.03"]. *)

val make :
  Plza_story.Steps.game_steps ->
  checkpoint:Plza_engine.Plan.checkpoint ->
  reload:(unit -> (unit, Engine_run.Failure.cause) result) ->
  Plza_engine.Game.t
(** The handlers for one checkpoint's run. *)

val run_watched :
  ?end_check:(unit -> (unit, Engine_run.Failure.cause) result) ->
  mode:string ->
  Watch_report.t ->
  Plza_engine.Game.t ->
  Plza_engine.Plan.checkpoint ->
  (unit, Plza_engine.Failure.t) result
(** The checkpoint through the runner, shown on the watch page
    ({!Plza_engine.Plan_watch}): the report's steps move with its events and its
    run in [mode] ends passed or failed. [end_check] (none by default) runs
    after the last event passed: its failure is the run's, at "end". *)
