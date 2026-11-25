(** PLZA's AutoStory as a game of the checkpoint engine ({!Plza_engine}): the
    handlers its plans use. The fork's action table
    (PokemonLZA_AutoStoryActionTable.cpp) for these actions:

    - the game's [walk] ({!Plza_walk.Walk}), walked rather than run before 03.03
      (as PokemonLZA_AutoStory.cpp walks them, before dash is unlocked).

    Where it differs: only the walk so far. The story's scenes, battles, catches
    and game actions come in later PRs; a plan that names one fails
    [no_handler].

    PLZA reads no position and no flag, and saves only by autosave: [save]
    fails; [reload] is the caller's (back to the latest autosave). *)

val walk_only : string -> bool
(** Whether a checkpoint's runs are walked: its id is before ["03.03"]. *)

val make :
  Plza_walk.Walk.game_steps ->
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
