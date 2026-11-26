(** Catch-target selection and local progress tracking for [frlg.dex_collection]
    ([--options target=...] and [--options species=...]).

    Stores caught species slugs in [dex_progress.json] inside the local FRLG
    config directory
    ([Repo_io.Repo_files.data_dir "GAMEPILOT_FRLG_CONFIG" "frlg"]) so
    [everything], [missing-on-dex], and [version-exclusive-uncaught] skip
    species already caught on prior runs. *)

(** Which species checkpoints to run. *)
type mode =
  | Everything  (** All species not yet recorded in local progress. *)
  | Missing_on_dex  (** Missing species, tracked via local progress. *)
  | Version_exclusive  (** FireRed/LeafGreen version-exclusive species. *)
  | Version_exclusive_uncaught
      (** Version-exclusive species not yet recorded in local progress. *)
  | Specific_list of string list
      (** Only the species named in [--options species=...]. *)

val of_options : Run_options.t -> (mode option, string) result
(** Parses [target] and [species] from [options]. Returns [Ok None] when the
    program does not declare [target]; returns [Error] when
    [target=specific-list] has no species or when [species] is passed with
    another target mode. *)

val is_version_exclusive : string -> bool
(** Whether [species] (slug, lower-case) is a FireRed or LeafGreen version
    exclusive. *)

val should_run : mode:mode -> caught:string list -> string option -> bool
(** Whether a checkpoint whose catch target is [species] ([None] for non-catch
    checkpoints such as shopping) should run under [mode] given locally recorded
    [caught] species. *)

val plan_species : Pokemon_engine.Plan.t -> string option
(** The first [wild_rng] or [capture] event's ["species"] slug in the plan, or
    [None] if the checkpoint does not catch a named species. *)

val load_caught : ?path:string -> unit -> (string list, string) result
(** Reads the locally recorded caught species list from [path] (default:
    [<data_dir>/dex_progress.json]). Missing file yields [Ok []]. *)

val record_caught : ?path:string -> string -> (unit, string) result
(** Adds [species] to the locally recorded caught list at [path] (creating
    parent directories if needed). *)

val filter_checkpoints :
  plan_dir:string ->
  mode:mode ->
  caught:string list ->
  string list ->
  (string list * (string * string) list, string) result
(** [filter_checkpoints ~plan_dir ~mode ~caught ids] returns [(kept, skipped)]
    where each entry of [skipped] is [(checkpoint_id, reason)]. *)
