(** Catch-target selection and local progress tracking for [frlg.dex_collection]
    ([--options target=...] and [--options species=...]).

    Stores per-species catch counts in [dex_progress.json] (version 2) inside
    the local FRLG config directory
    ([Repo_io.Repo_files.data_dir "GAMEPILOT_FRLG_CONFIG" "frlg"]) so
    [everything], [missing-on-dex], and [version-exclusive-uncaught] skip
    species whose recorded count has reached their target. Legacy version 1
    files ([{"caught": [...]}]) are read as count 1 per listed species; writes
    always emit version 2. *)

(** Which species checkpoints to run. *)
type mode =
  | Everything  (** All species whose recorded count is below target. *)
  | Missing_on_dex  (** Missing species, tracked via local progress counts. *)
  | Version_exclusive  (** FireRed/LeafGreen version-exclusive species. *)
  | Version_exclusive_uncaught
      (** Version-exclusive species whose recorded count is below target. *)
  | Specific_list of string list
      (** Only the species named in [--options species=...]. *)

type counts = (string * int) list
(** Sorted per-species catch counts: each pair is [(slug, count)] with
    [count > 0]. *)

val of_options : Run_options.t -> (mode option, string) result
(** Parses [target] and [species] from [options]. Returns [Ok None] when the
    program does not declare [target]; returns [Error] when
    [target=specific-list] has no species or when [species] is passed with
    another target mode. *)

val is_version_exclusive : string -> bool
(** Whether [species] (slug, lower-case) is a FireRed or LeafGreen version
    exclusive. *)

val count_of : counts -> string -> int
(** Recorded catch count for [species] ([0] when absent). *)

val required_count : string -> int
(** Target catch count for [species] (FireRed Kanto exclusive evolution-line
    counts: [ekans]=2, [growlithe]=2, [oddish]=3, [psyduck]=2, [shellder]=2,
    [electabuzz]=1, [scyther]=1; [1] for any other species). *)

val remaining : counts:counts -> ?target:int -> string -> int
(** How many catches of [species] are still needed ([max 0 (target - count)]),
    defaulting [target] to {!required_count}. *)

val should_run : mode:mode -> counts:counts -> string option -> bool
(** Whether a checkpoint whose catch target is [species] ([None] for non-catch
    checkpoints such as shopping) should run under [mode] given locally recorded
    [counts]. *)

val plan_species : Pokemon_engine.Plan.t -> string option
(** The first [wild_rng], [capture], or [gift_rng] event's ["species"] slug in
    the plan, or [None] if the checkpoint does not catch a named species. *)

val load_counts : ?path:string -> unit -> (counts, string) result
(** Reads per-species catch counts from [path] (default:
    [<data_dir>/dex_progress.json]). Accepts version 2
    ([{"version": 2, "counts": {...}}]) and legacy version 1
    ([{"caught": [...]}], treating each listed slug as count 1). Missing file
    yields [Ok []]. *)

val load_caught : ?path:string -> unit -> (string list, string) result
(** Reads the sorted list of species with recorded count greater than 0 from
    [path] (default: [<data_dir>/dex_progress.json]). *)

val record_caught : ?path:string -> string -> (unit, string) result
(** Increments [species]'s catch count by 1 in [path] (creating parent
    directories if needed) and writes the version 2 JSON format. *)

val filter_checkpoints :
  plan_dir:string ->
  mode:mode ->
  counts:counts ->
  string list ->
  (string list * (string * string) list, string) result
(** [filter_checkpoints ~plan_dir ~mode ~counts ids] returns [(kept, skipped)]
    where each entry of [skipped] is [(checkpoint_id, reason)]. *)
