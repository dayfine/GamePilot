(** Where one event of a running checkpoint is, as {!Runner.run} reports it to
    whoever follows the run (the watch page's plan). *)

type t =
  | Started
  | Passed
  | Skipped of string  (** the [skip_if] flag that held *)
  | Failed of string  (** the reason, as logged *)

val to_watch : t -> Wire.Watch.event_state * string
(** The event's state on the watch page and its detail (a failure's reason, the
    flag a skip held on). *)
