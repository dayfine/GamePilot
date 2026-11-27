(** One checkpoint run in its own daemon, as a game's live series runs it
    (FRLG's Checkpoint_live_run): the daemon started and always stopped, the
    session in the run's folder with a lost connection made a failure, the saves
    the session makes in that folder, and the run's ending printed and recorded.
    The game gives its own outcome type and how a failure makes one ([failed]).
*)

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

val run_live :
  failed:(failed -> 'o) -> dir:string -> port:int -> (Wire.backend -> 'o) -> 'o
(** [run_live ~failed ~dir ~port body] runs [Live.run_with_backend ~port body]
    inside {!in_session}, turning any unexpected exception into a non-repeating
    failure at ["raised"] so the run folder and watch run always close. *)

val finish :
  runs_dir:string ->
  Run_record.run ->
  summary:string ->
  Run_record.ending ->
  unit
(** Prints ["[Run] <folder>: <summary>"] and writes the run's ending. *)

val save : log:(string -> unit) -> string -> (unit -> int) -> unit
(** [save ~log what op]: a save in the session the daemon may refuse (an older
    daemon, a bad path), logged ["[Run] saved <what>"] or why it could not be;
    never fatal. Moved unchanged from FRLG's Checkpoint_live_run. *)

val save_failure :
  log:(string -> unit) -> Run_record.t -> save_states:bool -> unit
(** What a failed run saves in its folder (Run_record.failure_saves: the frame,
    and the state when [save_states]), each through [save]. *)
