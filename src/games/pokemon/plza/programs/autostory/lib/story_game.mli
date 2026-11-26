(** PLZA's AutoStory as a game of the checkpoint engine ({!Plza_engine}): runs
    each plan event through its handler over {!Plza_story.Steps}, as the fork's
    action table (PokemonLZA_AutoStoryActionTable.cpp) runs its actions, each
    action checking its own args ([bad_args]); a plan that names an action with
    no handler yet fails [no_handler]. An event's [skip_if] flags are read from
    the screen ({!Resume_flags}), where the fork resumes 01.03 by an option.

    PLZA reads no position, and saves only by autosave: [save] fails; [reload]
    is the caller's (back to the latest autosave). *)

val walk_only : string -> bool
(** Whether a checkpoint's runs are walked: its id is before ["03.04"]. *)

val make :
  ?options:New_game_options.t ->
  ?new_game:(Plza_story.New_game_choices.t -> Plza_story.Steps.outcome) ->
  Plza_story.Steps.game_steps ->
  checkpoint:Plza_engine.Plan.checkpoint ->
  reload:(unit -> (unit, Engine_run.Failure.cause) result) ->
  Plza_engine.Game.t
(** The handlers for one checkpoint's run; [new_game] plays 00.00-new-game's
    choices, the program's [options] (none by default) over the plan's (by
    default it fails [no_handler]: the live runner passes
    {!Live_intro_screen.run}). With a [story_battle] later in the checkpoint, a
    walk or a scene (but [scene_to_battle]) stops on the battle HUD and the run
    goes on at the battle ({!Battle_jump}). *)

val run_watched :
  ?end_state:
    Plza_rules.Postconditions.t
    * (Plza_rules.Postconditions.t -> Plza_rules.Postconditions.reads) ->
  mode:string ->
  Watch_report.t ->
  Plza_engine.Game.t ->
  Plza_engine.Plan.checkpoint ->
  (unit, Plza_engine.Failure.t) result
(** The checkpoint through the runner, shown on the watch page
    ({!Plza_engine.Plan_watch}): the report's steps move with its events and its
    run in [mode] ends passed or failed. [end_state] (none by default) is its
    end place and its reader ({!Start_signature.promised_end},
    {!Start_signature.read_end}): the runner passes the checkpoint with no event
    run when it already holds, and checks it after the last event. *)
