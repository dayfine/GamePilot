(** The effect set programs may use. Programs call these functions and never
    touch I/O; a handler (real daemon client, replay of a wire log, later a
    simulator) answers them. Every op is direct style: it returns when the
    handler has the answer. *)

type measurements = Wire.frame
(** The latest numbers from the subscribed probes, one per frame. *)

type template_hash = string
(** An uploaded template as the daemon names it: the lowercase hex SHA-256 of
    its PNG bytes. A [core.template_match@1] probe spec takes it
    ([Wire.template_match_probe]); it is valid for the rest of the connection.
*)

type awaited =
  | Holds of measurements  (** the first frame on which the predicate held *)
  | Timeout

(** How a {!race} ended. *)
type raced =
  | Finished of Wire.batch_done  (** the batch ran to its end *)
  | Stopped of measurements
      (** the first frame on which the stop reader held; the batch was cancelled
      *)

exception Rpc_error of Wire.error
(** The daemon answered a request with an error. *)

exception Disconnected of string
(** The handler lost its source of frames (socket closed, end of log). *)

(** {1 Effects} *)

type _ Effect.t +=
  | Submit : Wire.command list -> Wire.batch_done Effect.t
  | Await : (measurements -> bool) * int -> awaited Effect.t
  | Race : Wire.command list * (measurements -> bool) -> raced Effect.t
  | Now : float Effect.t
  | Read : measurements option Effect.t
  | Load_state : string -> int Effect.t
  | Upload_template : string -> template_hash Effect.t
  | Subscribe : Wire.probe_spec list -> string list Effect.t
  | Unsubscribe : string list -> string list Effect.t

(** {1 Ops} *)

val submit : Wire.command list -> Wire.batch_done
(** Queues one batch and returns when its [batch_done] arrives. *)

val await : timeout_ms:int -> (measurements -> bool) -> awaited
(** Returns [Holds m] for the first frame [m] (the latest one included) on which
    the predicate holds, or [Timeout] once a frame is more than [timeout_ms]
    later than [now ()] at the call. *)

val race : Wire.command list -> stop:(measurements -> bool) -> raced
(** Queues one batch and watches the frames while it runs. Returns
    [Finished done] when its [batch_done] arrives first, or [Stopped m] for the
    first frame [m] received after the batch was submitted on which [stop]
    holds. On a stop the handler sends [cancel] (which drops every queued
    command and releases all buttons) and returns once the daemon answered it,
    so the next op starts from released buttons. Frames received before the
    submit, the latest included, are not checked. *)

val now : unit -> float
(** Daemon clock in ms: the [t_ms] of the newest frame or [batch_done] seen. *)

val read : unit -> measurements option
(** The latest frame, if any arrived since subscribing. *)

(** {1 Setup ops} *)

val load_state : string -> int
(** Loads a save state; returns the frame [seq] after loading. *)

val upload_template : string -> template_hash
(** [upload_template png] registers a template from a PNG file's bytes and
    returns its hash. The handler sends each distinct PNG once per connection:
    uploading the same bytes again returns the first hash without a request. *)

val subscribe : Wire.probe_spec list -> string list
(** Subscribes probes; returns the subscribed ids. *)

val unsubscribe : string list -> string list
(** Stops measuring these probes; returns the ids that were subscribed. The
    latest frame ({!read}) drops their results too. *)

val with_probes : Wire.probe_spec list -> (unit -> 'a) -> 'a
(** [with_probes probes f] subscribes [probes], runs [f] and unsubscribes them,
    also when [f] raises (unless the connection is gone). A reader that measures
    once uses it so its probes do not cost time on every later frame. *)

(** {1 Helpers for readers} *)

val probe : measurements -> string -> Wire.probe_result option
