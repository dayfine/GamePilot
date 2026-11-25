(** PLZA's AutoStory as a game of the checkpoint engine ({!Plza_checkpoints}):
    the handlers 01.00a's to 03.11's plans use, over {!Plza_story.Steps}. The
    fork's action table (PokemonLZA_AutoStoryActionTable.cpp) for these actions:

    - [new_game], 01.00a's ({!Plza_story.New_game_intro}), with the fork's
      choices as optional args: [language] (a tag of
      {!Plza_story.New_game_choices.tags}, ["en"] when absent), [look] (1 to 8,
      1) and [name] (["Kosmos"]);
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
    - [choose_0] and [choose_1] ({!Plza_story.Choose_row}), no args;
    - [scene_to_battle], the fork's scene to a battle's start (to the battle
      HUD, with the lock-on), no args;
    - [scene_with_start_window], the fork's scene with a start window
      ([start_window_ms]: control before any scene waits that long for one), its
      one arg;
    - [scene_through_prompt], the fork's scene that presses A first: A on the
      prompt until the game takes it, then the scene; its one optional arg
      [stop_at_choice: true] (the fork's) stops at the choice. Where it differs:
      free control with no A prompt on two reads 300 ms apart fails
      [prompt_not_seen] before any A, where the fork presses A on nothing and
      its scene then ends on control, passing a walk that stopped short;
    - [story_battle] ({!Plza_story.Battle}), no args;
    - [talk_through_map_screen] ({!Plza_story.Map_talk}), no args;
    - [climb_ladder] ({!Plza_walk.Ladder_climb}), no args;
    - [run_to_gate] ({!Plza_walk.Gate_run}), with an optional [timeout_ms] (8 s,
      the fork's);
    - the game's [walk] ({!Plza_walk.Walk}), walked rather than run before 03.03
      (as PokemonLZA_AutoStory.cpp walks them, before dash is unlocked); its
      [end] ["talk"] or ["talk_after_legs"] (the fork's walk ending in a talk,
      and its walk to the starter) walks into a talk; the fork's [held: true] is
      the [style] ["steer"], its [wait_ms] the [wait_before_ms], its
      [end_after_ms] the [earliest_end_ms]. The fork's starter option
      (Totodile's or Tepig's legs in place of the plan's) is not ported: the
      plan walks to Chikorita, the fork's default.

    PLZA reads no position and no flag, and saves only by autosave: [save]
    fails; [reload] is the caller's (back to the latest autosave). *)

val walk_only : string -> bool
(** Whether a checkpoint's runs are walked: its id is before ["03.03"]. *)

val make :
  ?new_game:(Plza_story.New_game_choices.t -> Plza_story.Steps.outcome) ->
  Plza_story.Steps.game_steps ->
  checkpoint:Plza_checkpoints.Plan.checkpoint ->
  reload:(unit -> (unit, Engine_run.Failure.cause) result) ->
  Plza_checkpoints.Game.t
(** The handlers for one checkpoint's run; [new_game] plays 01.00a's choices (by
    default it fails [no_handler]: the live runner passes
    {!Live_intro_screen.run}). With a [story_battle] later in the checkpoint, a
    walk or a scene (but [scene_to_battle]) stops on the battle HUD and the run
    goes on at the battle ({!Battle_jump}). *)

val run_watched :
  ?end_check:(unit -> (unit, Engine_run.Failure.cause) result) ->
  mode:string ->
  Watch_report.t ->
  Plza_checkpoints.Game.t ->
  Plza_checkpoints.Plan.checkpoint ->
  (unit, Plza_checkpoints.Failure.t) result
(** The checkpoint through the runner, shown on the watch page
    ({!Plza_checkpoints.Plan_watch}): the report's steps move with its events
    and its run in [mode] ends passed or failed. [end_check] (none by default)
    runs after the last event passed: its failure is the run's, at "end"
    ({!Start_signature.check_end}). *)
