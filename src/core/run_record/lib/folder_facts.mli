(** What an old run folder says of its run without a run.json (gamepilot runs
    --backfill), as the hub reads it (daemon/src/run_history.h). *)

val wire_span : string -> (float * float) option
(** The t_ms of a wire log's first and last lines. *)

val backend : string -> string
(** daemon.json's backend, else daemon.out's first line's; [""] unknown. *)

val times : string -> int * int option
(** Start and end, Unix ms: daemon.json's clock zero and the wire log's last
    line; else the wire log's span back from its last write; else the folder's
    mtime and no end. *)

val of_folder : string -> (string * Yojson.Safe.t) list
(** run.json's backend, started_ms and (when known) ended_ms. *)

val preflight_verdict : string -> string list -> (string * Yojson.Safe.t) list
(** The result of a pre-flight's story.log: its last "[Preflight] <checkpoint>:
    ..." verdict line; none when it never finished. *)
