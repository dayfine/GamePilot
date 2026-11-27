(** Read-only loader for historical runs recorded in [<runs_dir>/RESULTS.tsv],
    used by [gamepilot ui] to display past run outcomes on the Hub landing page.
*)

type entry = {
  time : string;  (** ISO-8601 local timestamp of the run. *)
  game : string;  (** Game identifier (e.g. ["frlg"], ["plza"], ["bdsp"]). *)
  run : string;
      (** Run folder name (e.g. ["2026-11-26-bdsp.underground-run-15"]). *)
  checkpoint : string;  (** Program or checkpoint identifier. *)
  mode : string;  (** Run mode (e.g. ["testing"], ["verification"], ["run"]). *)
  result : string;  (** Outcome (["pass"], ["fail"], etc.). *)
  at : string;  (** Event where a failure occurred, or [""]. *)
  reason : string;  (** Failure summary, or [""]. *)
}
(** One row from [RESULTS.tsv]. *)

val default_limit : int
(** Default maximum number of recent entries returned (200). *)

val parse_tsv : ?limit:int -> string -> entry list
(** Pure parser for [RESULTS.tsv] contents; returns up to [limit] most recent
    entries (newest first). *)

val load : ?limit:int -> runs_dir:string -> unit -> entry list
(** Reads [<runs_dir>/RESULTS.tsv] when present; returns [[]] if missing. *)

val to_json : runs_dir:string -> entry list -> Yojson.Safe.t
(** Encodes [GET /api/history] JSON payload. *)
