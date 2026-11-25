(** The daemons of a checkpoint series, one per run (Daemon_run), each logging
    into its run's folder (wire.jsonl, daemon.out). Each asks for the ports the
    one before it bound, so the watch page keeps its URL across the series'
    runs, and the page's URLs are printed when they are new. Moved unchanged
    from FRLG's Checkpoint_live_run. *)

type t
(** The series' daemon settings and the ports its last daemon bound. *)

val create :
  daemon:string ->
  backend:Daemon_process.backend ->
  flags:string list ->
  port:int ->
  watch:Daemon_process.watch option ->
  t
(** [daemon] is the daemon's path, [flags] its recording and keep-awake flags as
    the user gave them, [port] the program's port asked for (0: any) and [watch]
    the watch page, if any. No daemon has run yet. *)

val with_daemon :
  t ->
  failed:(Daemon_run.failed -> 'o) ->
  Run_record.t ->
  checkpoint:string ->
  (Daemon_process.t -> 'o) ->
  'o
(** The body with a daemon started for the run [checkpoint] in that run's
    folder, stopped after it whatever happens (Daemon_run.with_daemon). It asks
    for the ports the last daemon bound, else the asked ones, and for the asked
    ones again when those are taken. The page's URLs are printed at the first
    run and whenever the ports change. *)
