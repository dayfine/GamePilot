(** PLZA's AutoStory as a game of the checkpoint engine ({!Plza_engine}): the
    handlers 01.00b's to 01.03's plans use, over {!Plza_story.Steps}. The fork's
    action table (PokemonLZA_AutoStoryActionTable.cpp) for these actions:

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
    - [scene_to_choice], the fork's scene stopping at a choice (a game action
      here, as the engine's scene takes no args), with an optional [button],
      ["A"] (when absent) or ["B"];
    - [choose_1] ({!Plza_story.Choose_row}), no args;
    - [scene_to_battle], the fork's scene to a battle's start (to the battle
      HUD, with the lock-on), no args;
    - [story_battle] ({!Plza_story.Battle}), no args;
    - the game's [walk] ({!Plza_walk.Walk}), walked rather than run before 03.03
      (as PokemonLZA_AutoStory.cpp walks them, before dash is unlocked); its
      [end] ["talk_after_legs"] (the fork's walk to the starter) walks into a
      talk. The fork's starter option (Totodile's or Tepig's legs in place of
      the plan's) is not ported: the plan walks to Chikorita, the fork's
      default.

    Where it differs: only 01.00b's to 01.03's actions so far. The other
    scenes', catches' and the later walks' come in later PRs; a plan that names
    one fails [no_handler]. An event's [skip_if] flags are read from the screen
    ({!Resume_flags}), where the fork resumes 01.03 by an option.

    PLZA reads no position, and saves only by autosave: [save] fails; [reload]
    is the caller's (back to the latest autosave). *)

val walk_only : string -> bool
(** Whether a checkpoint's runs are walked: its id is before ["03.03"]. *)

val make :
  Plza_story.Steps.game_steps ->
  checkpoint:Plza_engine.Plan.checkpoint ->
  reload:(unit -> (unit, Engine_run.Failure.cause) result) ->
  Plza_engine.Game.t
(** The handlers for one checkpoint's run. With a [story_battle] later in the
    checkpoint, a walk or a scene (but [scene_to_battle]) stops on the battle
    HUD and the run goes on at the battle ({!Battle_jump}). *)

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
