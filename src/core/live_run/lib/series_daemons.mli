(** The daemons of a checkpoint series, one per run (Daemon_run), each logging
    into its run's folder (wire.jsonl, daemon.out). Each asks for the ports the
    one before it bound, so the watch page keeps its URL across the series'
    runs, and the page's URLs are printed when they are new. Moved unchanged
    from FRLG's Checkpoint_live_run.

    The daemons know the series they serve: its checkpoints and mode at
    {!create}, each run as it starts ({!with_daemon}) and ends ({!finish}), and
    the series' end ({!finished}). These are what the watch page's series view
    needs, which only the runner knows: each goes on to the series' record
    ({!Series_watch}), nothing without a watch page. A game's series runner
    gives them here and nowhere else. *)

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
    page, if any. No daemon has run yet; the series' record is written
    ({!Series_watch.start}). *)

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
    ports change. The series' record has the run going
    ({!Series_watch.run_started}) before the daemon starts. *)

val finish :
  t ->
  runs_dir:string ->
  Run_record.run ->
  summary:string ->
  Run_record.ending ->
  unit
(** The run ended: {!Daemon_run.finish}, the series' runner calling this in its
    place, then the series' record ({!Series_watch.run_ended}). *)

val finished : t -> passed:bool -> unit
(** The series ended, [passed] as its policy decided (not by its last run). The
    series' record says so ({!Series_watch.finished}). *)

(** What post-series [--close-game] should do once a series finishes. *)
type close_game_action =
  | Close_game
      (** [--close-game] was given on a passing Switch series: return to HOME
          and close the running game. *)
  | Skip_failed_run
      (** [--close-game] was given on a Switch series that did not pass: skip so
          the console keeps its failure state for debugging. *)
  | No_close
      (** [--close-game] was not given, or the backend is not a Switch. *)

val close_game_action :
  close_game:bool ->
  backend:Daemon_process.backend ->
  passed:bool ->
  close_game_action
(** Decides whether to close the running Switch game after a series finishes. *)

val close_game_after_pass :
  t ->
  close_game:bool ->
  ?tile:Switch.Home_screen.tile_color ->
  passed:bool ->
  unit ->
  bool
(** When [--close-game] is set on a passing Switch series, starts a short-lived
    daemon (without recording or a watch page), returns to Switch HOME and
    closes the running game ({!Switch.Console_park.park_and_close}), and stops
    the daemon afterward. Returns [true] on success or when skipped/no-op, and
    [false] if closing the game failed. *)
