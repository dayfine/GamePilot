(** A plan's run on the watch page ({!Watch_report}): its events as the steps,
    moved by the runner's progress, its story lines and its run. What every path
    that runs a plan shows: a checkpoint, and the shadow plans ({!Shadow_plan})
    of the pre-flight and the make-room party read. *)

val create : Story.Plan.checkpoint -> Watch_report.t
(** The checkpoint's events, all pending; shows the plan. *)

val on_event : Watch_report.t -> int -> Story.Event_progress.t -> unit
(** The runner's progress of event [i], shown. *)

val options : (string -> unit) -> Checkpoint_run.options
(** A run that loads no state (its own events go back to the save), reads the
    party when it needs it, runs, logs to the function. *)

val run :
  mode:string ->
  ?actions:((string -> unit) -> (string * Story.Game.game_action) list) ->
  Checkpoint_run.options ->
  Frlg_overworld.Frlg_steps.world ->
  Story.Plan.t ->
  (unit, Story.Failure.t) result
(** In the effect context: the plan through {!Checkpoint_run.run}, shown with
    its run in [mode] (["single"], ["preflight"]) from start to end, failed when
    the run raises (re-raised). Every story line goes to the options' log and to
    the page. [actions], made for that log, are the caller's own game actions: a
    shadow plan's. *)

val run_shadow :
  mode:string ->
  log:(string -> unit) ->
  Frlg_overworld.Frlg_steps.world ->
  Story.Plan.t ->
  ((string -> unit) -> (string * Story.Game.game_action) list) ->
  (unit, Story.Failure.t) result
(** {!run} with {!options}. *)
