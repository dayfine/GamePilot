(** PLZA's checkpoints on the Switch (Plza_autostory.Story_game through the
    engine, Plza_checkpoints.Runner): each run its own daemon (the program's
    viewport, native) and run folder (Live_run.Daemon_run), as FireRed's, but
    without save states or an in-game save: PLZA saves by autosave. A plan's
    start signature (minimap, party count, A prompt, wild zone) is checked
    before each run (Plza_autostory.Start_signature). The series' first run
    starts where the console is, put there by hand (01.00b on the new game's
    Confirm Choices, 01.01 on the platform); every later run of the same
    checkpoint first goes back to the latest autosave
    (Plza_autostory.Game_reload), which 01.00b cannot (its start is no save):
    its second run is refused. A passing checkpoint hands the console to the
    next one as it ends. Its daemons keep the console awake with the right stick
    (keepawake_stick), and each checkpoint wakes the screen before it reads it
    (Plza_story.Screen_wake). The watch page shows each run's plan, its events
    moving with the runner (Story_game.run_watched), and the run. *)

val load_plan :
  plan_dir:string -> string -> (Plza_checkpoints.Plan.t, string) result
(** The plan [<plan_dir>/<id>.plan.json], decoded. *)

val run_series :
  plan_dir:string ->
  Flags.t ->
  backend:Live_run.Daemon_process.backend ->
  viewport:string option ->
  string list ->
  (int, string) result
(** The checkpoints [ids], in order, each run until the policy decides; every
    plan loaded and checked ({!Plza_autostory.Plan_check}) before the console
    moves. [Ok 0] when every one passed, [Ok 1] when one stopped; the Switch
    only. *)
