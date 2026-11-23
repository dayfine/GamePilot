(** The effect set programs may use. Programs call these functions and never
    touch I/O; a handler (real daemon client, replay of a wire log, later a
    simulator) answers them. Every op is direct style: it returns when the
    handler has the answer. *)

type measurements = Wire.frame
(** The latest numbers from the subscribed probes, one per frame. *)

type awaited =
  | Holds of measurements  (** the first frame on which the predicate held *)
  | Timeout

exception Rpc_error of Wire.error
(** The daemon answered a request with an error. *)

exception Disconnected of string
(** The handler lost its source of frames (socket closed, end of log). *)

(** {1 Effects} *)

type _ Effect.t +=
  | Submit : Wire.command list -> Wire.batch_done Effect.t
  | Await : (measurements -> bool) * int -> awaited Effect.t
  | Now : float Effect.t
  | Read : measurements option Effect.t
  | Load_state : string -> int Effect.t
  | Subscribe : Wire.probe_spec list -> string list Effect.t

(** {1 Ops} *)

val submit : Wire.command list -> Wire.batch_done
(** Queues one batch and returns when its [batch_done] arrives. *)

val await : timeout_ms:int -> (measurements -> bool) -> awaited
(** Returns [Holds m] for the first frame [m] (the latest one included) on which
    the predicate holds, or [Timeout] once a frame is more than [timeout_ms]
    later than [now ()] at the call. *)

val now : unit -> float
(** Daemon clock in ms: the [t_ms] of the newest frame or [batch_done] seen. *)

val read : unit -> measurements option
(** The latest frame, if any arrived since subscribing. *)

(** {1 Setup ops} *)

val load_state : string -> int
(** Loads a save state; returns the frame [seq] after loading. *)

val subscribe : Wire.probe_spec list -> string list
(** Subscribes probes; returns the subscribed ids. *)

(** {1 Helpers for readers} *)

val probe : measurements -> string -> Wire.probe_result option
