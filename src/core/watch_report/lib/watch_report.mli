(** What a run shows on the watch page beside the video, whatever the path (a
    checkpoint, the pre-flight, the make-room party read, a one-shot program):
    its steps with their states and times ([watch.plan], the whole plan at each
    change, a few hundred bytes), every story line ([watch.log]) and, for a run
    that is not part of a chain, the run itself ([watch.run]: its mode and its
    one checkpoint, current, then passed or failed). In the effect context only.
    Times are wall clock (Unix ms), not the daemon's: the page shows them across
    daemons. *)

type t

val create : checkpoint:string -> string list -> t
(** The run's steps in order (the plan's event ids, or a path's own step ids
    such as ["soft_reset"]), all pending; shows the plan. *)

val set : t -> int -> Wire.Watch.event_state -> string -> unit
(** Step [i] (0-based) in a new state with its detail (a failure's reason, the
    flag a skip held on); shows the plan. An index out of range is ignored. *)

val step : t -> string -> (unit -> 'a) -> 'a
(** [step t id f]: the first step [id] that has not ended is current while [f]
    runs, then done. When [f] raises, the step fails with the exception's text
    and the exception goes on. *)

val current : t -> string option
(** The running or failed step as a failure names it: ["#3 talk_clerk"]. *)

val start_run : t -> mode:string -> unit
(** [watch.run]: the run's one checkpoint is current. *)

val end_run : t -> passed:bool -> unit
(** [watch.run]: the checkpoint passed or failed, with its time. *)

val log : (string -> unit) -> string -> unit
(** [log base line]: the line to [base] (the run's story log) and to the page.
*)

val counters : Wire.Watch.counter list -> unit
(** [counters items]: [watch.counters], updating the live Counters card on the
    watch page. *)

val now_ms : unit -> int
(** Current wall-clock time in Unix epoch milliseconds. *)
