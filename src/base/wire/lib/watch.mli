(** What a running program shows on the watch page ([gamepilot watch]): its
    checkpoint's events with their states ([watch.plan]) and its story log
    ([watch.log]), sent to the daemon as notifications; and the daemon's [stop]
    notification when someone pressed Stop there. *)

type json = Yojson.Safe.t
(** A decoded JSON value: a notification's params. *)

(** Where an event of the checkpoint stands. *)
type event_state =
  | Pending  (** not started yet *)
  | Current  (** running now *)
  | Done  (** finished as planned *)
  | Failed  (** it failed; its [detail] says why *)
  | Skipped
      (** not run, because the game already held its result; its [detail] names
          the flag that showed it *)

type plan_event = {
  id : string;  (** the event's id in the plan *)
  state : event_state;
  detail : string;
      (** A failure's reason, the flag a skip held on, else empty. *)
  started_ms : int option;
      (** When it last started, Unix ms (v1.8); none while pending. *)
  ended_ms : int option;  (** When it ended, Unix ms (v1.8); none until then. *)
}
(** One event of the checkpoint's plan, as the watch page lists it: its state
    and its times. *)

type plan = { checkpoint : string; events : plan_event list }
(** A [watch.plan] notification: the checkpoint's id and its events, in plan
    order. *)

val pending : string -> plan_event
(** An event that has not started. *)

val stamp : now_ms:int -> plan_event -> event_state -> string -> plan_event
(** [stamp ~now_ms e state detail]: [e] in its new state with [detail], its
    times updated: starting ([Current]) sets the start and clears the end;
    ending ([Done], [Failed], [Skipped]) sets the end, and the start too when it
    never started (a skip), so it took no time. *)

val event_ms : now_ms:int option -> plan_event -> int option
(** An event's time: a finished one's from start to end, the current one's from
    its start to [now_ms] (none when the plan is not live). None before it
    started or without times (a v1.7 program). The watch page's [eventMs]. *)

val plan_ms : now_ms:int option -> plan -> int option
(** The checkpoint's time: from its first start to its last end, or to [now_ms]
    while an event runs. The watch page's [planMs]. *)

val plan_of_json : json -> plan
(** A [watch.plan] notification's params; a missing field or an unknown state is
    a [Decode_error]. *)

val json_of_plan : plan -> json
(** A [watch.plan] notification's params, as {!plan_of_json} reads them. *)

val line_of_json : json -> string
(** A [watch.log] notification's line. *)

val json_of_line : string -> json
(** A [watch.log] notification's params for this line. *)

type counter = {
  label : string;
  value : string;
  until_ms : int option;
      (** Optional countdown target in Unix epoch milliseconds. When set, the
          watch page ticks the remaining time live in the browser; omitted from
          JSON when [None]. *)
}
(** One live counter row in a [watch.counters] notification (v1.22). *)

val counter : ?until_ms:int -> string -> string -> counter
(** [counter ?until_ms label value] builds a {!counter} row, defaulting
    [until_ms] to [None]. *)

val counters_of_json : json -> counter list
(** A [watch.counters] notification's items. *)

val json_of_counters : counter list -> json
(** A [watch.counters] notification's params for these items. *)

val reason_of_json : json -> string
(** A [stop] notification's reason. *)

val json_of_reason : string -> json
(** A [stop] notification's params for this reason. *)
