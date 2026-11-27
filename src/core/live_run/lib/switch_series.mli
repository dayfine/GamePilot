(** Shared Switch-only testing-mode series plumbing over {!Series_daemons},
    {!Daemon_run}, {!Watch_report}, and {!Switch.Initial_screen}. Games supply
    their own attempt logic, plan watch report constructor, and outcome type;
    this module owns daemon lifecycle, initial-screen gating, session guarding,
    failure capture, and run summary formatting. *)

val ending_of :
  result_of:('o -> (unit, string * string) result) ->
  string ->
  'o ->
  string * Run_record.ending
(** Formats a run's summary line and {!Run_record.ending} via
    {!Series_daemons.format_ending} from [result_of outcome]. *)

val run_guarded :
  failed:(repeats:bool -> at:string -> reason:string -> 'o) ->
  already_at_start:bool ->
  log:(string -> unit) ->
  picture:Wire.box ->
  expectation:Switch.Initial_screen.expectation ->
  Watch_report.t ->
  (unit -> 'o) ->
  'o
(** Checks the console's initial screen unless continuing from a passing
    checkpoint ({!Switch.Initial_screen.check_unless_chained}), then runs
    [body ()] inside {!Daemon_run.guard_session}. Ends [report] as failed on
    initial-screen mismatch, stop request, or raised exception. *)

val run_attempt :
  daemons:Series_daemons.t ->
  runs_dir:string ->
  checkpoint_id:string ->
  n:int ->
  attempt:int ->
  ?banner_suffix:string ->
  already_at_start:bool ->
  expectation:Switch.Initial_screen.expectation ->
  create_report:(unit -> Watch_report.t) ->
  failed:(repeats:bool -> at:string -> reason:string -> 'o) ->
  result_of:('o -> (unit, string * string) result) ->
  (log:(string -> unit) -> picture:Wire.box -> Watch_report.t -> 'o) ->
  'o
(** Starts a testing-mode run folder and daemon via
    {!Series_daemons.start_and_run}, runs [body] guarded by {!run_guarded},
    captures a failure frame on error ({!Daemon_run.save_failure} with
    [~save_states:false]), and formats the run's ending via {!ending_of}. *)

val run_series :
  daemon:string ->
  runs_dir:string ->
  backend:Daemon_process.backend ->
  viewport:string option ->
  ?program_flags:string list ->
  daemon_flags:string list ->
  port:int ->
  watch:Daemon_process.watch option ->
  close_game:bool ->
  info:Run_record.info ->
  checkpoints:string list ->
  (Series_daemons.t -> bool) ->
  int
(** Creates testing-mode {!Series_daemons.t} via
    {!Series_daemons.create_for_runs}, runs [body daemons] to get whether the
    series passed, and finishes via {!Series_daemons.finish_series}, returning
    the process exit code. *)
