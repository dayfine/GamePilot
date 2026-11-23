(** Live handler: a stdlib-only JSON-RPC client of the daemon.

    One TCP connection to [127.0.0.1:port]; one reader thread parses lines and
    feeds a [Mutex]/[Condition] queue that {!Session} drains. Writes nothing to
    disk (the daemon keeps the wire log). *)

val default_port : int
(** 47900 *)

val run : ?port:int -> (unit -> 'a) -> 'a
(** Connects, runs the program under {!Session.run} and closes the connection.
    Raises [Unix.Unix_error] if the daemon is not listening. *)
