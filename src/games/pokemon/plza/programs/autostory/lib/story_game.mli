(** PLZA's AutoStory as a game of the checkpoint engine ({!Plza_checkpoints}):
    the handlers 01.00b's to 01.02's plans use, over {!Plza_story.Story_steps}.
    The fork's action table (PokemonLZA_AutoStoryActionTable.cpp, [plza/lean])
    for these actions:

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
      ["end_on_black_fade"] for the fork's [end_on_black_fade: true];
    - [scene_to_choice], the fork's [scene] with [stop_at_choice: true] (a game
      action here, as the engine's scene takes no args), with an optional
      [button], ["A"] (when absent) or ["B"];
    - [choose_0] and [choose_1] ({!Plza_story.Choose_row}), no args;
    - the game's [walk] ({!Plza_walk.Walk}), walked rather than run before 03.03
      (the fork's [RUN_FROM], before dash is unlocked).

    PLZA reads no position and no flag, and saves only by autosave: [save]
    fails; [reload] is the caller's (back to the latest autosave). *)

val walk_only : string -> bool
(** Whether a checkpoint's runs are walked: its id is before ["03.03"]. *)

val make :
  Plza_story.Story_steps.game_steps ->
  checkpoint_id:string ->
  reload:(unit -> (unit, Engine_run.Failure.cause) result) ->
  Plza_checkpoints.Game.t
(** The handlers for one checkpoint's run. *)

val run_watched :
  mode:string ->
  Watch_report.t ->
  Plza_checkpoints.Game.t ->
  Plza_checkpoints.Plan.checkpoint ->
  (unit, Plza_checkpoints.Failure.t) result
(** The checkpoint through the runner, shown on the watch page
    ({!Plza_checkpoints.Plan_watch}): the report's steps move with its events
    and its run in [mode] ends passed or failed. *)
