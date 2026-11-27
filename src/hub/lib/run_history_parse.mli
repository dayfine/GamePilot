(** Pure parsing helpers for historical run folder names, local timestamps, and
    [RESULTS.tsv] rows used by {!Run_history}. *)

type tsv_row = {
  ended_ms : int;  (** Parsed local timestamp in Unix milliseconds, or [0]. *)
  checkpoint : string;  (** Checkpoint or program column from [RESULTS.tsv]. *)
  mode : string;  (** Mode column from [RESULTS.tsv]. *)
  result : string;  (** Outcome column from [RESULTS.tsv]. *)
  at : string;  (** Event where a failure occurred, or [""]. *)
  reason : string;  (** Failure summary, or [""]. *)
}
(** One parsed data row from [RESULTS.tsv]. *)

val valid_run_name : string -> bool
(** True when a directory name is a safe run folder name (non-empty, at most 200
    ASCII identifier characters, not starting with ['.']). *)

val parse_run_name : string -> (string * string) option
(** Parses ["YYYY-MM-DD-<checkpoint>-<mode>-<n>"] into [(checkpoint, mode)]. *)

val local_time_ms : string -> int
(** Parses ["YYYY-MM-DDTHH:MM:SS"] in local time to Unix milliseconds, or [0].
*)

val parse_tsv_line : string -> (string * tsv_row) option
(** Parses one [RESULTS.tsv] line into [(run_name, row)], skipping blank and
    header lines. *)

val tsv_table : string -> (string, tsv_row) Hashtbl.t
(** Indexes [RESULTS.tsv] rows by run name; a later row for the same run wins.
*)

val infer_game_from_id : string -> string
(** Extracts a lowercase alphabetic prefix before ['.'] (e.g. ["bdsp"] from
    ["bdsp.underground"]), rejecting numeric prefixes such as ["01"]. *)

val lookup_program :
  program:string -> checkpoint:string -> Program_registry.t option
(** Resolves a {!Program_registry.t} by program id, checkpoint id, or bundled
    checkpoint plan membership. *)

val game_name_of_id : string -> string
(** Returns the registered display name for a game id, or [""] if unknown. *)
