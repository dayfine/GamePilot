(** [plza.bank-home]'s checkpoints on the Switch, as PLZA's story series runs
    its own ([Plza_series.Runs]): each run its own daemon (the program's
    viewport, native; Live_run.Series_daemons, so the watch page keeps its URL)
    and run folder (Live_run.Daemon_run), its plan's events moving on the watch
    page. Each run first finds Legends: Z-A's tile on the Switch's HOME menu
    ({!Plza_bank_home.Bank_home_game.start_check}), then runs its events
    ({!Plza_bank_home.Bank_home_game.make}). Unlike the story's series, a run is
    one attempt with no reload (a failed bank leaves Pokémon HOME open, unsaved,
    for a look) and the daemon's keep-awake is left as given: the Switch's HOME
    menu and Pokémon HOME have no camera to nudge. *)

val run_series :
  program:(string * string) list ->
  options:Run_options.t ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series ~program ~options ~viewport plan_dir args]: the checkpoints
    --from to --to of the plan folder, in order, each run until the policy
    decides; every plan loaded and checked with the run's options
    ({!Plza_bank_home.Bank_home_game.check_plan}) before the console moves.
    [program] is run.json's program fields, [options] the program's options,
    checked (Program_registry.check_options), [viewport] the Switch daemons'.
    [Ok 0] when every one passed, [Ok 1] when one stopped; the Switch only,
    testing, the flags of {!Bank_home_flags}. *)
