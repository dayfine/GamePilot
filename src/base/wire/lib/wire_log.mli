(** The daemon's wire log: every message it sent or received, one per line.
    [conn] is the client connection a message went to or came from (absent in
    logs from before many clients, and on the daemon's own lines); [owner] is
    the input lease's owner on an input line (contracts v1.9). *)

type json = Yojson.Safe.t
type direction = In | Out | Daemon

type log_line = {
  dir : direction;
  t_ms : float;
  conn : int option;
  owner : string option;
  msg : Jsonrpc.message;
}

val log_line_of_json : json -> log_line
val json_of_log_line : log_line -> json
