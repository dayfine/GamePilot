(** The daemons of a checkpoint series, one per run (Daemon_run), each logging
    into its run's folder (wire.jsonl, daemon.out). Each asks for the ports the
    one before it bound, so the watch page keeps its URL across the series'
    runs, and the page's URLs are printed when they are new. Moved unchanged
    from FRLG's Checkpoint_live_run.

    The daemons know the series they serve: its checkpoints and mode at
    {!create}, each run as it starts ({!with_daemon}) and ends ({!finish}), and
    the series' end ({!finished}). These are what a watch page's series view
    needs, which only the runner knows; a game's series runner gives them here
    and nowhere else. *)

type series = {
  info : Run_record.info;  (** What each run's run.json says of the series. *)
  mode : string;
      (** The series' own mode (testing, verification), whatever its runs'. *)
  checkpoints : string list;  (** The selected checkpoints, in run order. *)
}
(** The series the daemons serve. *)

type t
(** The series, its daemon settings and the ports its last daemon bound. *)

val create :
  daemon:string ->
  backend:Daemon_process.backend ->
  flags:string list ->
  port:int ->
  watch:Daemon_process.watch option ->
  series ->
  t
(** The daemons of that series, all its checkpoints to come. [daemon] is the
    daemon's path, [flags] its recording and keep-awake flags as the user gave
    them, [port] the program's port asked for (0: any) and [watch] the watch
    page, if any. No daemon has run yet. *)

val series : t -> series
(** The series given to {!create}. *)

val with_daemon :
  t ->
  failed:(Daemon_run.failed -> 'o) ->
  Run_record.run ->
  n:int ->
  (Daemon_process.t -> 'o) ->
  'o
(** The body with a daemon started for the run, run [n] of its checkpoint (the
    run says which attempt), logging in that run's folder, stopped after it
    whatever happens (Daemon_run.with_daemon). It asks for the ports the last
    daemon bound, else the asked ones, and for the asked ones again when those
    are taken. The page's URLs are printed at the first run and whenever the
    ports change. *)

val finish :
  t ->
  runs_dir:string ->
  Run_record.run ->
  summary:string ->
  Run_record.ending ->
  unit
(** The run ended: {!Daemon_run.finish}, the series' runner calling this in its
    place. *)

val finished : t -> passed:bool -> unit
(** The series ended, [passed] as its policy decided (not by its last run).
    Nothing more yet: a hook for the watch page's series view. *)
