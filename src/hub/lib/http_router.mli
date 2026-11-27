(** HTTP request router for [gamepilot ui], decoupled from sockets so every
    endpoint can be exercised directly in unit tests without opening a TCP port.
*)

val route : Run_manager.t -> string -> string -> string -> int * string * string
(** [route mgr meth path body] returns [(status_code, content_type, resp_body)]
    for one HTTP request. *)
