(** The scheduler shared by every handler that speaks the wire protocol.

    It owns the client side of a session (request ids, batch ids, the latest
    frame, the daemon clock, the templates uploaded on the connection) and
    answers the effects from a {!transport}. The real handler's transport is a
    socket plus a reader thread; the replay handler's transport is a recorded
    wire log. Both see the same scheduler, so a replay takes the same decisions
    the live run took. *)

type event = Client_connection.event =
  | Message of Wire.message
  | Idle  (** nothing arrived for a while; lets [await] check the wall clock *)
  | Closed of string  (** no more messages, with the reason *)

type transport = Client_connection.transport = {
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

val run :
  ?client:string ->
  ?lease:string * int option ->
  transport ->
  (unit -> 'a) ->
  'a
(** Sends [hello] (as [client], default {!client_name}), takes the input lease
    when [lease] gives its owner and ttl (contracts v1.9: else the first input
    takes it, owned by [client]; a refusal raises [Effects.Rpc_error] before the
    program starts), then runs the program with the effects handled. Raises
    [Effects.Rpc_error], [Effects.Disconnected] or [Protocol_error]. After the
    daemon's [stop], every wait on the game ([submit], [race], [await], and the
    first results of a [subscribe]) raises [Effects.Stop_requested] into the
    program; plain requests (saves, [unsubscribe]) still run, so the program's
    failure path works. [show_plan], [show_log] and [show_run] go out as
    [watch.plan], [watch.log] and [watch.run] notifications. *)

val run_with_backend :
  ?client:string ->
  ?lease:string * int option ->
  transport ->
  (Wire.backend -> 'a) ->
  'a
(** {!run}, the program given what the daemon drives (its [hello]'s [backend]:
    the frame, where the game picture sits in it). *)
