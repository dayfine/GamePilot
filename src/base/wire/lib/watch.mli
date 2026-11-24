(** What a running program shows on the watch page ([gamepilot watch]): its
    checkpoint's events with their states ([watch.plan]) and its story log
    ([watch.log]), sent to the daemon as notifications; and the daemon's [stop]
    notification when someone pressed Stop there. *)

type json = Yojson.Safe.t
type event_state = Pending | Current | Done | Failed | Skipped

type plan_event = {
  id : string;
  state : event_state;
  detail : string;
      (** A failure's reason, the flag a skip held on, else empty. *)
  started_ms : int option;
      (** When it last started, Unix ms (v1.8); none while pending. *)
  ended_ms : int option;  (** When it ended, Unix ms (v1.8); none until then. *)
}

type plan = { checkpoint : string; events : plan_event list }

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
val json_of_plan : plan -> json

val line_of_json : json -> string
(** A [watch.log] notification's line. *)

val json_of_line : string -> json

val reason_of_json : json -> string
(** A [stop] notification's reason. *)

val json_of_reason : string -> json
