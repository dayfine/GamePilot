(** Where one event of a running checkpoint is, as {!Runner.run} reports it to
    whoever follows the run (the watch page's plan). *)

type t =
  | Started
  | Passed
  | Skipped of string  (** the [skip_if] flag that held *)
  | Failed of string  (** the reason, as logged *)
