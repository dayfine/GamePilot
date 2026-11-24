(** The daemon's wire log: every message it sent or received, one per line. *)

type json = Yojson.Safe.t
type direction = In | Out | Daemon
type log_line = { dir : direction; t_ms : float; msg : Jsonrpc.message }

val log_line_of_json : json -> log_line
val json_of_log_line : log_line -> json
