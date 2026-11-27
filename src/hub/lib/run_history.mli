(** Read-only loader for historical runs under [<runs_dir>], merging per-run
    [run.json], [daemon.json], [summary.txt], and [RESULTS.tsv] metadata for the
    [gamepilot ui] Hub page. *)

type entry = {
  run : string;
      (** Run folder name (e.g. ["2026-11-26-bdsp.underground-run-15"]). *)
  kind : string;
      (** Run kind (["checkpoints"], ["preflight"], ["daemon"], etc.). *)
  game : string;  (** Game identifier (e.g. ["frlg"], ["plza"], ["bdsp"]). *)
  game_name : string;  (** Display name of the game, or [""]. *)
  program : string;
      (** Registered program id (e.g. ["frlg.supplies"]), or [""]. *)
  program_name : string;  (** Display name of the program, or [""]. *)
  group : string;  (** Program category name (e.g. ["Farming"]), or [""]. *)
  checkpoint : string;  (** Checkpoint or program identifier. *)
  from : string;  (** Start checkpoint id of the run's range, or [""]. *)
  to_ : string;  (** End checkpoint id of the run's range, or [""]. *)
  backend : string;
      (** Backend id (["mgba"], ["switch"], ["view"], or [""]). *)
  mode : string;
      (** Run mode (["testing"], ["verification"], ["run"], etc.). *)
  result : string;
      (** Outcome (["pass"], ["fail"], ["running"], ["unknown"]). *)
  at : string;  (** Event where a failure occurred, or [""]. *)
  reason : string;  (** Failure summary, or [""]. *)
  started_ms : int;  (** Unix timestamp in milliseconds when the run started. *)
  ended_ms : int;  (** Unix timestamp in milliseconds when the run ended. *)
  recorded : bool;  (** True when recorded frames exist for this run. *)
}
(** One historical run row returned by [GET /api/history]. *)

val default_limit : int
(** Default maximum number of recent entries returned (500). *)

val watch_hub_port : int
(** Default TCP port of the daemon Watch Hub serving [/runs/<run>/] and [/live].
*)

val parse_tsv : ?limit:int -> string -> entry list
(** Pure parser for [RESULTS.tsv] contents; returns up to [limit] most recent
    entries (newest first). *)

val load : ?limit:int -> runs_dir:string -> unit -> entry list
(** Scans [runs_dir] for run folders and merges [run.json], [daemon.json],
    [summary.txt], and [RESULTS.tsv] metadata, returning up to [limit] entries
    sorted newest first. Returns [[]] if [runs_dir] does not exist. *)

val to_json : runs_dir:string -> entry list -> Yojson.Safe.t
(** Encodes the [GET /api/history] JSON payload including [runs_dir],
    [watch_hub_port], and [entries]. *)
