(** The JSON-RPC 2.0 envelope: calls by method, responses by id, and the
    notifications: [frame], [batch_done] and [stop] from the daemon,
    [watch.plan], [watch.log] and [watch.run] from the program. *)

type json = Yojson.Safe.t
(** A decoded JSON value: a whole message, or a result or error's data. *)

type error = { code : int; message : string; data : json option }
(** A JSON-RPC error answer: its [code] (e.g. {!Lease.held_code}), a message for
    a person, and the details some errors carry (a lease refusal's holder). *)

(** A request's method and its params: what a client asks the daemon to do. *)
type call =
  | Hello of { protocol : int; client : string }
      (** [hello]: the protocol version the client speaks and its name, which
          the daemon shows in [status] and the lease *)
  | Load_state of { path : string }
      (** [backend.load_state]: load the emulator save state at [path] *)
  | Reset
      (** [backend.reset]: power-cycle the emulator (mGBA only), holding at the
          first frame after *)
  | Save_state of { path : string }
      (** [backend.save_state]: save the emulator's state to [path] *)
  | Save_frame of { path : string }
      (** [backend.save_frame]: save the current frame as a PNG at [path] *)
  | Upload_template of { png : string }
      (** [probe.upload_template]: a template image's PNG bytes (base64 on the
          wire), for template probes to match against *)
  | Subscribe of Probe.probe_spec list
      (** [subscribe]: start running these probes on every frame *)
  | Unsubscribe of string list
      (** [unsubscribe]: stop the probes with these ids *)
  | Submit of { batch_id : string; commands : Command.command list }
      (** [submit]: queue a batch of commands, named [batch_id] in its
          [batch_done] *)
  | Cancel  (** [cancel]: drop every queued batch and release every button *)
  | Cancel_then of { batch_id : string; commands : Command.command list }
      (** [cancel] with [then]: drop the queued batches and run this one in
          their place, at once *)
  | Status  (** [status]: ask for the daemon's health ({!Daemon_status.t}) *)
  | Lease_acquire of { owner : string; ttl_ms : int option }
      (** [lease.acquire]: take the input lease under the label [owner], for
          [ttl_ms] without input (the daemon's default when absent) *)
  | Lease_release  (** [lease.release]: give the input lease back *)

type request = { id : int; call : call }
(** A call with the id its response will carry. *)

type response = { id : int; outcome : (json, error) result }
(** The answer to the request with this [id]: its result object, or an error. *)

(** A message no one answers. *)
type notification =
  | Frame of { load : int; frame : Probe.frame }
      (** [frame], from the daemon: the subscribed probes' results on a new
          frame, and how many loads had succeeded when it was taken *)
  | Batch_done of Command.batch_done
      (** [batch_done], from the daemon: a submitted batch has run *)
  | Watch_plan of Watch.plan
      (** [watch.plan], from the program: its checkpoint's events *)
  | Watch_log of string  (** [watch.log], from the program: one log line *)
  | Watch_run of Watch_run.t
      (** [watch.run], from the program: its chain of checkpoints *)
  | Stop of string
      (** [stop], from the daemon: someone pressed Stop on the watch page, for
          this reason *)
  | Keepawake of { key : string; idle_ms : int }
      (** [keepawake], a daemon line of the wire log: it pressed [key] to keep
          the console awake after [idle_ms] with no input *)

(** Any JSON-RPC message: a request, its response, or a notification. *)
type message =
  | Request of request  (** a call that wants an answer *)
  | Response of response  (** the answer to a request *)
  | Notification of notification  (** a message no one answers *)

val method_name : call -> string
(** The call's method on the wire, e.g. ["backend.load_state"]. *)

val message_of_json : json -> message
(** One decoded message; an unknown method or a malformed envelope or params is
    a [Decode_error]. *)

val json_of_message : message -> json
(** One message, as {!message_of_json} reads it. *)

val message_of_string : string -> message
(** One message from its JSON text; bad JSON is a [Decode_error] too. *)

val string_of_message : message -> string
(** One message as one line of JSON text. *)
