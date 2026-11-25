(** The daemon's wire log: every message it sent or received, one per line.
    [conn] is the client connection a message went to or came from (absent in
    logs from before many clients, and on the daemon's own lines); [owner] is
    the input lease's owner on an input line (contracts v1.9). *)

type json = Yojson.Safe.t
(** A decoded JSON value: one line of the log. *)

(** Which way a logged message went ([dir] on the wire). *)
type direction =
  | In  (** a client sent it to the daemon (["in"]) *)
  | Out  (** the daemon sent it to a client (["out"]) *)
  | Daemon
      (** the daemon did it on its own, sent to no client (["daemon"]), such as
          a keep-awake press *)

type log_line = {
  dir : direction;
  t_ms : float;  (** when, on the daemon clock *)
  conn : int option;
  owner : string option;
  msg : Jsonrpc.message;  (** the JSON-RPC message itself *)
}
(** One line of the log: one message, which way it went, when, and on which
    connection. *)

val log_line_of_json : json -> log_line
(** One line; a missing field or an unknown [dir] is a [Decode_error]. *)

val json_of_log_line : log_line -> json
(** One line, as {!log_line_of_json} reads it; absent [conn] and [owner] are
    left out. *)
