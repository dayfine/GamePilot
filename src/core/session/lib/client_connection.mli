(** The client's side of one connection to the daemon: request and batch ids,
    the answers not yet taken, the latest frame with every probe's held result,
    the daemon clock, and a stop the daemon asked for. {!Session} answers the
    effects from it. *)

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

type t = {
  transport : transport;
  mutable next_id : int;
  mutable next_batch : int;
  mutable latest : Wire.frame option;
  mutable load : int;  (** from the last [backend.load_state] reply *)
  mutable now : float option;
  mutable stop : string option;
      (** the reason of a [stop] the daemon sent; it stays set *)
  responses : (int, (Wire.json, Wire.error) result) Hashtbl.t;
  dones : (string, Wire.batch_done) Hashtbl.t;
  templates : (Digest.t, Effects.template_hash) Hashtbl.t;
      (** uploaded on this connection, by the MD5 of their PNG bytes *)
  mutable held : string option;
      (** the batch a [Race_held] stopped and left running, until a [Replace]
          takes its place *)
}

val create : transport -> t

val protocol_error : ('a, unit, string, 'b) format4 -> 'a
(** Raises {!Protocol_error} with the formatted message. *)

val pump : t -> Wire.frame option
(** Takes one event from the transport; returns the frame, with the held results
    it did not repeat, if the event was one. Raises [Effects.Disconnected] when
    the transport closed. *)

val pump_until : t -> (unit -> 'a option) -> 'a
(** Pumps until [ready] gives a value. *)

val take : ('k, 'v) Hashtbl.t -> 'k -> unit -> 'v option
(** Removes and returns the entry, as a [ready] for {!pump_until}. *)

val send_request : t -> Wire.call -> int
(** Sends the call with a fresh id; returns the id. *)

val result_of : (Wire.json, Wire.error) result -> Wire.json
(** The result, or [Effects.Rpc_error]. *)

val call : t -> Wire.call -> Wire.json
(** Sends the call and pumps until its answer. A plain call does not check
    {!check_stop}: the failure path a stop starts still saves and unsubscribes.
*)

val check_stop : t -> unit
(** Raises [Effects.Stop_requested] once the daemon sent a [stop]: every wait on
    the game ([submit], [race], [await]) calls it before each event it takes. *)
