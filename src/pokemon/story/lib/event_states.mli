(** The save states a checkpoint run on mGBA keeps at each event's start, so a
    fix can be tested from just before the changed event ({!Event_range}):
    [<states>/<checkpoint>.events/<n>-<event>.ss], [n] the event's number from 1
    (two digits), one per event, the newest run's. A run keeps an event's state
    only when it reached that event cleanly: every event it ran before it passed
    or was skipped.

    Beside each state, [<n>-<event>.start.json] keeps what the run read at the
    checkpoint's start: a postcondition that depends on the start (the money
    spent) is checked against the checkpoint's start, not re-read at the event,
    so a partial run checks the same promise a whole run does. Not in the fork.
*)

val dir : states:string -> checkpoint:string -> string
(** [<states>/<checkpoint>.events]. *)

val file : index:int -> event_id:string -> string
(** ["13-trade_chding.ss"] for event [index] (from 0) [12]. *)

val path :
  states:string -> checkpoint:string -> index:int -> event_id:string -> string

val kept_path : string -> string
(** What is kept beside a state: [13-trade_chding.ss] -> [13-trade_chding.json].
*)

val is_other_state : index:int -> keep:string -> string -> bool
(** A file of the events folder that is an older state (or its start reads) of
    event [index] under another id (or what is kept beside it), to remove once
    [keep] is saved: a renamed event leaves one state per number. *)

type kept = {
  start_money : int option;
      (** The money at the checkpoint's start, when a promise of the money spent
          needs it. *)
  at : Pose.observed option;  (** Where the player was reckoned to stand. *)
}

val kept_to_json : kept -> Yojson.Safe.t
val kept_of_json : Yojson.Safe.t -> (kept, string) result

val missing : checkpoint:string -> label:string -> path:string -> string
(** No state for the event yet: says so and names the run that would make one.
*)

(** {1 Which events get a state} *)

type tracker
(** The events a run has heard so far. *)

val tracker : first:int -> tracker
(** For a run whose first event is [first] (0 for a whole run). *)

val hear : tracker -> int -> Event_progress.t -> bool
(** Hears event [index]'s progress; [true] when its state is to be kept now: it
    started and every event from [first] before it passed or was skipped. *)
