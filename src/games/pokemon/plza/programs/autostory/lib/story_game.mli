(** PLZA's AutoStory as a game of the checkpoint engine ({!Plza_engine}): runs
    each plan event through its handler over {!Plza_story.Steps}, as the fork's
    action table (PokemonLZA_AutoStoryActionTable.cpp) runs its actions, each
    action checking its own args ([bad_args]); a plan that names an action with
    no handler yet fails [no_handler]. An event's [skip_if] flags are read from
    the screen ({!Resume_flags}), where the fork resumes 01.03 by an option.

    PLZA reads no position, and saves only by autosave: [save] fails; [reload]
    is the caller's (back to the latest autosave). *)

val walk_only : string -> bool
(** Whether a checkpoint's runs are walked: its id is before ["03.03"]. *)

type program_actions =
  log:(string -> unit) ->
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  (string * Plza_engine.Game.game_action) list
(** A program's own game actions, beside the story's ({!make}), made by its
    runner in each run's session: its log, the game picture and the uploaded
    reader templates. *)

val make :
  ?program_actions:(string * Plza_engine.Game.game_action) list ->
  Plza_story.Steps.game_steps ->
  checkpoint:Plza_engine.Plan.checkpoint ->
  reload:(unit -> (unit, Engine_run.Failure.cause) result) ->
  Plza_engine.Game.t
(** The handlers for one checkpoint's run: the story's actions, then
    [program_actions] (none by default), the actions of the program whose plans
    these are, as its runner hands them in. With a [story_battle] later in the
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
    after the last event passed: its failure is the run's, at "end"
    ({!Start_signature.check_end}). *)
