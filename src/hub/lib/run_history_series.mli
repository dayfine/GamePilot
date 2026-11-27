(** Loader for checkpoint series records under
    [<runs_dir>/.watch/series/*.json], collapsing each multi-checkpoint series
    into one {!t} and tracking its covered child run names so {!Run_history}
    does not list them separately. *)

type run = {
  run : string;  (** Child run folder name. *)
  result : string;  (** Child run outcome, or [""]. *)
  at : string;  (** Event where a failure occurred, or [""]. *)
  reason : string;  (** Failure summary, or [""]. *)
}
(** One child run listed inside a checkpoint of a series record. *)

type checkpoint = {
  id : string;  (** Checkpoint identifier. *)
  state : string;
      (** Checkpoint state (["passed"], ["failed"], ["current"], ["pending"],
          ["skipped"]). *)
  runs : run list;  (** Child runs executed for this checkpoint. *)
}
(** One checkpoint inside a series record. *)

type t = {
  series : string;  (** Series identifier (filename stem and URL slug). *)
  game : string;  (** Game identifier, or [""]. *)
  game_name : string;  (** Display name of the game, or [""]. *)
  program : string;  (** Registered program id, or [""]. *)
  program_name : string;  (** Display name of the program, or [""]. *)
  group : string;  (** Program category name, or [""]. *)
  from : string;  (** Start checkpoint id, or [""]. *)
  to_ : string;  (** End checkpoint id, or [""]. *)
  mode : string;  (** Run mode, or [""]. *)
  backend : string;  (** Backend id, or [""]. *)
  started_ms : int;  (** Series start timestamp in Unix milliseconds. *)
  ended_ms : int;  (** Series end timestamp in Unix milliseconds, or [0]. *)
  result : string;  (** Series outcome (["pass"], ["fail"], ["running"]). *)
  active_run : string;  (** Currently running child run name, or [""]. *)
  checkpoints : checkpoint list;  (** Checkpoints in run order. *)
}
(** Parsed [<runs_dir>/.watch/series/<id>.json] record. *)

val parse : Yojson.Safe.t -> t option
(** Parses a series JSON value into a record, returning [None] if the object
    lacks a valid [series] id. *)

val child_runs : t -> string list
(** Returns all child run folder names referenced by a series record (checkpoint
    runs and any active run). *)

val focus_checkpoint : t -> string
(** Returns the failed or currently running checkpoint id of a series, or [""].
*)

val failure : t -> string * string
(** Returns [(at, reason)] from the first failing child run when the series
    failed, or [("", "")]. *)

val read_dir : runs_dir:string -> t list
(** Scans [<runs_dir>/.watch/series/*.json] and returns all valid series
    records, or [[]] if the folder does not exist. *)

val has_recorded_frames : string -> bool
(** True when [<dir>/frames/index.jsonl] exists. *)

val any_recorded : runs_dir:string -> t -> bool
(** True when any child run folder of a series has recorded frames. *)

val covered_runs : t list -> Set.Make(String).t
(** Collects all child run folder names covered by the given series records. *)
