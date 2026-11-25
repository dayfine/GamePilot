(** One checkpoint run in its own daemon, as a game's live series runs it
    (FRLG's Checkpoint_live_run): the daemon started and always stopped, the
    session in the run's folder with a lost connection made a failure, and the
    run's ending printed and recorded. The game gives its own outcome type and
    how a failure makes one ([failed]). *)

type failed = { at : string; reason : string; repeats : bool }
(** A run that failed: where, why, and whether another run would fail the same
    way (the series then stops). *)

val with_daemon :
  failed:(failed -> 'o) ->
  (Daemon_process.t, string) result ->
  (Daemon_process.t -> 'o) ->
  'o
(** The body with the started daemon, stopped after it whatever happens; a
    daemon that did not start fails at ["daemon"], repeating. *)

val in_session : failed:(failed -> 'o) -> dir:string -> (unit -> 'o) -> 'o
(** The session (a [Live.run]) with [dir] as the run folder. A lost connection
    fails at ["session"] (not repeating) and a Unix error at ["session"]
    (repeating); any other exception goes on to the caller. *)

val finish :
  runs_dir:string ->
  Run_record.run ->
  summary:string ->
  Run_record.ending ->
  unit
(** Prints ["[Run] <folder>: <summary>"] and writes the run's ending. *)
