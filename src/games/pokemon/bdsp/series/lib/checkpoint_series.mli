(** A BDSP program's checkpoints on the Switch, each run in its own daemon
    ({!Live_run.Series_daemons}) and run folder ({!Live_run.Daemon_run}), driven
    through {!Engine_series.Series_runner} and {!Bdsp_engine}. *)

type failure = {
  at : string;
      (** Where the run failed (e.g. ["start"], event id, ["stop"]). *)
  reason : string;  (** Human-readable failure description. *)
  repeats : bool;
      (** Whether repeating the run without intervention would fail the same
          way. *)
}
(** Details of a failed checkpoint attempt. *)

(** Result of one checkpoint run. *)
type outcome =
  | Passed  (** Every event of the checkpoint passed. *)
  | Failed of failure  (** The checkpoint failed before completing. *)

type action_runner =
  log:(string -> unit) ->
  picture:Wire.box ->
  options:Run_options.t ->
  Bdsp_rules.Action.t ->
  (unit, Engine_run.Failure.cause) result
(** Runs one BDSP checkpoint action inside the active live session with the
    checked program [options]. *)

type program = {
  check_plans : Bdsp_engine.Plan.t list -> (unit, string) result;
      (** Checks the selected plans in run order before the console moves. *)
  daemon_flags : string list;
      (** Daemon flags prepended before the user's flags. *)
  initial_screen : Bdsp_engine.Plan.t -> Switch.Initial_screen.expectation;
      (** Screen expected before a cold-start or retry attempt begins. *)
  run_action : action_runner;
      (** Executes each BDSP action in a checkpoint plan. *)
}
(** Program-specific hooks supplied to {!run_series}. *)

val load_plan : plan_dir:string -> string -> (Bdsp_engine.Plan.t, string) result
(** Loads and decodes [<plan_dir>/<id>.plan.json]. *)

val select_range :
  plan_dir:string ->
  Flags.t ->
  (Engine_series.Plan_folder.selection, string) result
(** Resolves the selected checkpoint range in [plan_dir]. When [--from] and
    [--to] are omitted, selects every checkpoint in [plan_dir] in run order. *)

val run_series :
  program ->
  program_fields:(string * string) list ->
  options:Run_options.t ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series program ~program_fields ~options ~viewport plan_dir args] parses
    [args], validates and loads the selected plans, runs them through
    {!Engine_series.Series_runner} and {!Live_run.Series_daemons} on the Switch,
    and returns [Ok 0] when every checkpoint passed or [Ok 1] when one failed.
*)
