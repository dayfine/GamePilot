(** A run's folder under the runs folder and what goes in it: run.json at the
    start and with the result at the end, summary.txt, KEEP, the RESULTS.tsv
    row. Every run path writes through {!start} and {!finish}. *)

type t = { dir : string; name : string }
(** A run folder: its path and its name. *)

val date : unit -> string
(** Today, local: ["2026-11-23"]. *)

val time : unit -> string
(** Now, local: ["2026-11-23T21:57:22"]. *)

val make_dirs : string -> unit
(** The folder and its parents. *)

val create : runs_dir:string -> checkpoint:string -> mode:string -> t
(** The first free [<date>-<checkpoint>-<mode>-<n>] folder, made. *)

val path : t -> string -> string
(** A file in the folder. *)

val write : t -> string -> string -> unit
(** Writes a file in the folder. *)

val story_log : t -> (string -> unit) * (unit -> unit)
(** A logger to stdout and story.log, and what closes it. *)

val copy_file : src:string -> dst:string -> unit

val modes : string list
(** The modes a folder's name may end in: testing, verification, preflight,
    single, run, bring-up. *)

val parse_name : string -> (string * string) option
(** ["<date>-<label>-<mode>-<n>"]: the label (a checkpoint, a program) and the
    mode, one of {!modes}. *)

(** What ran: a series' run, the pre-flight, one checkpoint, a one-shot program,
    the Switch's bring-up checks. *)
type kind = Checkpoints | Checkpoint | Program | Preflight | Bring_up

val kind_name : kind -> string

type info = {
  kind : kind;
  program : (string * string) list;
      (** The registry's run fields (game, program, names, group); [] for no
          program. *)
  from_id : string;
  to_id : string;
  backend : string;
}
(** What run.json says of a run besides its outcome. *)

type ending = { result : string; at : string; reason : string }
(** [result]: pass or fail. *)

val now_ms : unit -> int
(** Unix ms. *)

type run = {
  record : t;
  info : info;
  checkpoint : string;
  mode : string;
  started_ms : int;
}
(** A started run. *)

val run_json : run -> ended_ms:int -> ending option -> Yojson.Safe.t
(** run.json: without the end fields while [None]. *)

val start : runs_dir:string -> info -> checkpoint:string -> mode:string -> run
(** The run's folder ({!create}) and its run.json. *)

val finish : runs_dir:string -> run -> summary:string -> ending -> unit
(** summary.txt, KEEP on a failure, run.json with the result, the RESULTS.tsv
    row. *)

module Folder_facts = Folder_facts
(** What an old folder says of its run (gamepilot runs --backfill). *)
