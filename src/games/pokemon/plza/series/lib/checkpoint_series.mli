(** A PLZA program's checkpoints on the Switch, each run its own daemon (the
    program's viewport, native; Live_run.Series_daemons, so the watch page keeps
    its URL across runs) and run folder (Live_run.Daemon_run), as FireRed's, but
    without save states or an in-game save: PLZA saves by autosave. Within a run
    ({!Run_attempts}), an attempt found off its start reloads once and checks
    again, and a plan's [retries] reload and try again; each attempt is its own
    run folder. A passing checkpoint hands the console to the next one as it
    ends. The watch page shows each run's plan, its events moving with the
    runner, and the run. What each attempt does on the console is the program's
    ({!program}). Moved from plza.autostory's series (Plza_series.Runs) when
    plza.bank-home came. *)

type attempt =
  log:(string -> unit) ->
  picture:Wire.box ->
  reload:bool ->
  Watch_report.t ->
  Plza_engine.Plan.t ->
  Run_attempts.outcome
(** One attempt of a plan, in its daemon's session: [picture] is the hello's
    game picture, [reload] that it goes back to the latest autosave first, the
    report the watch page's run of the plan, whose run the attempt ends. An
    exception it lets out fails the attempt here, the watch run ended. *)

type program = {
  check_plans : Plza_engine.Plan.t list -> (unit, string) result;
      (** The series' plans checked, in run order, before the console moves. *)
  daemon_flags : string list;
      (** Its daemons' flags before the user's (plza.autostory's keep-awake
          stick). *)
  attempt : attempt;
}
(** What a program's runs do. *)

val load_plan : plan_dir:string -> string -> (Plza_engine.Plan.t, string) result
(** The plan [<plan_dir>/<id>.plan.json], decoded. *)

val failed :
  ?repeats:bool -> ?off_start:bool -> string -> string -> Run_attempts.outcome
(** [failed at reason]: a failed attempt; [repeats] and [off_start] false unless
    given. *)

val run_series :
  program ->
  program_fields:(string * string) list ->
  options:Run_options.t ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series program ~program_fields ~options ~viewport plan_dir args]: the
    checkpoints --from to --to of the plan folder, in order, each run until the
    policy decides; every plan loaded, then checked ([program.check_plans]),
    before the console moves. A checkpoint's first run starts where the console
    is (the series' start, or where the checkpoint before it ended) unless its
    plan's execution says [reload_when_chained]; every later run first reloads.
    [program_fields] is run.json's program fields, [options] the program's
    options, checked (Program_registry.check_options), for run.json, [viewport]
    the Switch daemons' (the registry's check of --viewport). [Ok 0] when every
    one passed, [Ok 1] when one stopped; the Switch only, testing ({!Flags}). *)
