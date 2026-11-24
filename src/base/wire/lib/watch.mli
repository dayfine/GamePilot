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
}

type plan = { checkpoint : string; events : plan_event list }

val plan_of_json : json -> plan
val json_of_plan : plan -> json

val line_of_json : json -> string
(** A [watch.log] notification's line. *)

val json_of_line : string -> json

val reason_of_json : json -> string
(** A [stop] notification's reason. *)

val json_of_reason : string -> json
