(** A checkpoint series' record ({!Series_record}) where the hub reads it:
    [<registry>/series/<id>.json], beside the daemons' entries, rewritten whole
    at each change (written aside, then renamed, so the hub never reads half of
    it). With it the hub lists the series as one entry, serves its page at
    [/series/ID/] and passes that page through to the daemon of the run going
    (docs/design/Watch-Page.md, One page per series). A game's series runner
    starts it once and tells it of each run; without a watch page every call is
    a no-op. *)

type t

val start :
  Daemon_process.watch option ->
  Run_record.info ->
  mode:string ->
  string list ->
  t
(** The series of the given checkpoints, in run order, all to come; its id is
    ["<date>-<from>-<to>-<pid>"], the runner's pid. *)

val id : t -> string option
(** None without a watch page. *)

val file : registry:string -> string -> string
(** The record of the series with that id. *)

val run_started : t -> Run_record.run -> n:int -> unit
(** Run [n] of a checkpoint started in its folder: {!Series_record.begin_run}.
*)

val run_ended : t -> Run_record.run -> Run_record.ending -> unit
val finished : t -> passed:bool -> unit
