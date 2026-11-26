(** PLZA's checkpoints on the Switch (Plza_autostory.Story_game through the
    engine, Plza_engine.Runner): each run its own daemon (the program's
    viewport, native; Live_run.Series_daemons, so the watch page keeps its URL
    across runs) and run folder (Live_run.Daemon_run), as FireRed's, but without
    save states or an in-game save: PLZA saves by autosave. A plan's start
    signature is checked before each run (Plza_autostory.Start_signature). The
    series' first run starts where the console is, put there by hand
    (01-to-the-platform on the new game's Confirm Choices, 02-platform-to-plaza
    on the platform); every later run of the same checkpoint first goes back to
    the latest autosave (Plza_autostory.Game_reload), which 01-to-the-platform
    cannot (its start is no save): its second run is refused. Within a run
    (Plza_autostory.Run_attempts), a checkpoint found off its start (its start
    signature, or an action's own start check) reloads once and checks again,
    and a plan's [retries] reload and try again; each attempt is its own run
    folder. A passing checkpoint hands the console to the next one as it ends.
    Its daemons keep the console awake with the right stick (keepawake_stick),
    and each checkpoint wakes the screen before it reads it
    (Plza_story.Screen_wake). The watch page shows each run's plan, its events
    moving with the runner (Story_game.run_watched), and the run. *)

val load_plan : plan_dir:string -> string -> (Plza_engine.Plan.t, string) result
(** The plan [<plan_dir>/<id>.plan.json], decoded. *)

val run_series :
  program:(string * string) list ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series ~program ~viewport plan_dir args]: the checkpoints --from to
    --to of the plan folder, in order, each run until the policy decides; every
    plan loaded and checked ({!Plza_autostory.Plan_check}) before the console
    moves. [program] is run.json's program fields, [viewport] the Switch
    daemons' (the registry's check of --viewport). [Ok 0] when every one passed,
    [Ok 1] when one stopped; the Switch only, testing. *)
