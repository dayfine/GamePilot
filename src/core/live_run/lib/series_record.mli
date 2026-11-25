(** What the watch page shows of a checkpoint series
    ([gamepilot run --from --to]) as one run (docs/design/Watch-Page.md, One
    page per series): every checkpoint in run order with its state, its runs
    (the run folder, run [n], attempt, result) and its times; the run going now,
    whose daemon the hub passes the series' page through to; and the series'
    end. Each run has its own daemon, so no daemon knows the series: the runner
    keeps this record and {!Series_watch} writes it where the hub reads it.
    Pure; the caller gives the clock (Unix ms).

    A series goes on to a checkpoint only after the one before passed, so a run
    of the next checkpoint marks the one before passed; the runner says how the
    series ended ({!finish}). *)

type t
(** One series' record. *)

val create :
  id:string ->
  pid:int ->
  Run_record.info ->
  mode:string ->
  started_ms:int ->
  string list ->
  t
(** The series [id] of the runner [pid] (the hub lists it while that process
    lives), its checkpoints in run order, all to come. *)

val begin_run : t -> Run_record.run -> n:int -> t
(** Run [n] of a checkpoint (its attempt from the run's [attempt], 1 without)
    starts in its run folder: the checkpoint is current and the run is the one
    going. A checkpoint the series did not list (a generated one) goes after the
    current one. *)

val end_run : t -> Run_record.run -> Run_record.ending -> now_ms:int -> t
(** The run ended: its result, and no run going until the next starts. *)

val finish : t -> passed:bool -> now_ms:int -> t
(** The series ended: the current checkpoint passed or failed, and after a
    failure the checkpoints to come are skipped. *)

val id : t -> string
(** The id {!create} was given. *)

val to_json : t -> Yojson.Safe.t
(** The record the hub serves ([/series/ID/series.json]): the series' fields
    (with run.json's program fields), ["result"] ([running], [pass] or [fail]),
    ["run"] (the run going, absent between runs) and ["checkpoints"]. *)
