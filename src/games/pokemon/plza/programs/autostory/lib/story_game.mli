(** PLZA's AutoStory as a game of the checkpoint engine ({!Plza_checkpoints}):
    the handlers 01.00b's and 01.01's plans use, over {!Plza_story.Story_steps}.
    The fork's action table (PokemonLZA_AutoStoryActionTable.cpp, [plza/lean])
    for these actions:

    - [confirm_new_game] ({!Plza_story.New_game_confirm}), no args;
    - [opening_to_platform] and [wait_for_platform]
      ({!Plza_story.Platform_wait}), with an optional [timeout_ms] (240 s and
      180 s when absent);
    - [set_text_speed_fast] ({!Plza_story.Text_speed}) and [plus_skip]
      ({!Plza_story.Plus_skip}), no args;
    - the engine's [scene] ({!Plza_story.Scene_machine}): its [action]
      ["end_on_black_fade"] for the fork's [end_on_black_fade: true];
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
