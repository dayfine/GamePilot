(** Replay handler: runs a program against a recorded wire log
    ([protocol/v1/14-wire_log.line.json] format) instead of the daemon.

    Daemon output ([dir = out]) is fed to the program in log order: frames,
    [batch_done] notifications and responses. Each message the program sends
    must match the next client message ([dir = in]) in the log; the program's
    clock is the daemon's [t_ms] from the log. The program may not read output
    that the daemon only produced after a client message the program has not
    sent yet: that, or any mismatch, is a {!Divergence}.

    Compared fields: method and id for every request; probes for [subscribe];
    the PNG bytes (the base64 payload) for [probe.upload_template]; commands,
    then batch id, for [submit]. [hello] and [backend.load_state] params are not
    compared (client names and state paths vary by machine).

    A log of a daemon that served several clients replays the program's
    connection only: the one that sent the log's first client message.

    Pure: no sockets, no clock, nothing written. *)

exception Divergence of string
(** Names the log line and what the program and the log each did. *)

type log

val log_of_lines : string list -> log
(** One JSON object per line; blank lines are skipped. Raises
    [Wire.Decode_error] with the line number on a bad line. *)

val log_of_file : string -> log

val run : log -> (unit -> 'a) -> 'a
(** Runs the program against the log. Raises {!Divergence} (also when the
    program returns before sending every client message the log has, naming the
    first one it did not send, unless one of its waits timed out at a recorded
    point: then it is on its own failure path), or [Effects.Disconnected] when
    the program waits past the end of the log. *)
