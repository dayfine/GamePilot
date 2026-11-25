(** What flags PLZA's series runner ({!Runs}) takes: the ones it is given, and
    the command's others, which it refuses rather than ignores. *)

type t = {
  from_id : string;
  to_id : string;
  runs : int option;  (** --runs: each checkpoint's runs in testing. *)
  runs_dir : string;
  daemon : string;  (** The daemon's path. *)
  backend_name : string;  (** As run.json names it: ["switch"]. *)
  watch : Live_run.Daemon_process.watch option;
  daemon_flags : string list;  (** The user's, passed to each daemon. *)
  program : (string * string) list;  (** run.json's program fields. *)
}
(** What the series is given. *)

type others = {
  mode : Engine_run.Checkpoint_trials.mode option;
  preflight : bool;
  from_event : string option;
  to_event : string option;
}
(** The command's flags this runner does not take. *)

val takes : others -> (unit, string) result
(** The flags this runner takes: testing whole checkpoints; [Error] names the
    ones given that it refuses (--mode other than testing, --preflight,
    --from-event, --to-event). *)
