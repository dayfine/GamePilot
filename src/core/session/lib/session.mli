(** The scheduler shared by every handler that speaks the wire protocol.

    It owns the client side of a session (request ids, batch ids, the latest
    frame, the daemon clock) and answers the effects from a {!transport}. The
    real handler's transport is a socket plus a reader thread; the replay
    handler's transport is a recorded wire log. Both see the same scheduler, so
    a replay takes the same decisions the live run took. *)

type event =
  | Message of Wire.message
  | Idle  (** nothing arrived for a while; lets [await] check the wall clock *)
  | Closed of string  (** no more messages, with the reason *)

type transport = {
  send : Wire.message -> unit;
  recv : unit -> event;  (** blocks until the next event *)
  wall_ms : unit -> float;
      (** local clock; only used when frames stop arriving *)
}

exception Protocol_error of string
(** The other side broke the protocol (e.g. sent a request to the client). *)

val stall_slack_ms : float
(** [await] also times out when [timeout_ms] plus this much local time passed
    without frames reaching the deadline (frames stalled). *)

val client_name : string
(** Sent in [hello]. *)

val run : transport -> (unit -> 'a) -> 'a
(** Sends [hello], then runs the program with the effects handled. Raises
    [Effects.Rpc_error], [Effects.Disconnected] or [Protocol_error]. *)
