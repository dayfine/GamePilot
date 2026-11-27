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
    pokemon_home.bank-plza came. *)

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
  with_end_place :
    next:Plza_engine.Plan.t option ->
    Plza_engine.Plan.t ->
    (Plza_engine.Plan.t, string) result;
      (** The plan with its end place in its postconditions, from the plan after
          it in the folder ([None] after the last): plza.autostory's is its own
          [place], else the next checkpoint's start signature. *)
  daemon_flags : string list;
      (** Its daemons' flags before the user's (plza.autostory's keep-awake
          stick). *)
  initial_screen : Plza_engine.Plan.t -> Switch.Initial_screen.expectation;
      (** What screen the console must show before an attempt starts (checked by
          {!Switch.Initial_screen.check} on cold starts, retries, later trials,
          and reloads; skipped when continuing directly from a passing
          checkpoint without a reload). *)
  attempt : attempt;
}
(** What a program's runs do. *)

val keepawake_stick : string list
(** The daemon flags that keep PLZA's console awake with the right stick:
    [--keepawake-key RStick]. The daemon's keep-awake presses B after 180 s idle
    on the Switch, and B backs out of PLZA's new-game menus (console B,
    2026-11-25); the right stick only turns the camera in the field and does
    nothing in a dialogue, a menu or a battle (up then down, so the camera's
    heading never moves: walk legs are aimed from it). Off, an idle console
    dimmed its screen, which reads as nothing (01.03's run 2). A
    [--keepawake-key] given on the command line comes after, and the daemon
    takes the last. *)

val each_plan :
  (Plza_engine.Plan.t -> (unit, string) result) ->
  Plza_engine.Plan.t list ->
  (unit, string) result
(** A [check_plans] of one check per plan, in order: the first [Error]. *)

val next_id : string -> string list -> string option
(** The checkpoint after [id] in a folder's run order, if any. *)

val no_end_place :
  next:Plza_engine.Plan.t option ->
  Plza_engine.Plan.t ->
  (Plza_engine.Plan.t, string) result
(** A [with_end_place] for a program whose plans promise no end place: the plan
    unchanged, so each runs its events. *)

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
    then given its end place ([program.with_end_place]), before the console
    moves. A checkpoint's first run starts where the console is (the series'
    start, or where the checkpoint before it ended) unless its plan's execution
    says [reload_when_chained]; every later run first reloads. [program_fields]
    is run.json's program fields, [options] the program's options, checked
    (Program_registry.check_options), for run.json, [viewport] the Switch
    daemons' (the registry's check of --viewport). [Ok 0] when every one passed,
    [Ok 1] when one stopped; the Switch only, testing ({!Flags}). *)
