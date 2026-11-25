(** PLZA's checkpoints on the Switch (Plza_autostory.Story_game through the
    engine, Plza_engine.Runner): each run its own daemon (the program's
    viewport, native) and run folder (Live_run.Daemon_run), as FireRed's, but
    without save states or an in-game save: PLZA saves by autosave. The series'
    first run starts where the console is, put there by hand; a passing
    checkpoint hands the console to the next one as it ends. Its daemons keep
    the console awake with the right stick (keepawake_stick). The watch page
    shows each run's plan, its events moving with the runner
    (Story_game.run_watched), and the run.

    Where it differs: the skeleton. No run goes back to the latest autosave yet,
    so a checkpoint's second run (--runs 2) is refused before it starts; no
    start signature is checked and no plan retries. *)

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
    plan loaded before the console moves. [program] is run.json's program
    fields, [viewport] the Switch daemons' (the registry's check of --viewport).
    [Ok 0] when every one passed, [Ok 1] when one stopped; the Switch only,
    testing. *)
