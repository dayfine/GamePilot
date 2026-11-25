(** A run on a daemon that is already up (gamepilot run --plan, gamepilot run
    <program>): a run folder of its own in --runs-dir ($GAMEPILOT_RUNS) through
    Run_record, so the hub lists it like a series' run. The wire log stays with
    the daemon. *)

val default_runs_dir : unit -> string
(** $GAMEPILOT_RUNS, else [$HOME/.local/share/gamepilot/runs]. *)

val runs_dir_flag : string list -> (string * string list, string) result
(** [--runs-dir DIR] out of the args, wherever it is, and the other args; else
    $GAMEPILOT_RUNS, else [$HOME/.local/share/gamepilot/runs]. *)

val start :
  runs_dir:string ->
  kind:Run_record.kind ->
  program:(string * string) list ->
  label:string ->
  mode:string ->
  (Run_record.run, string) result
(** The run's folder, started and printed. [program]: run.json's program fields
    (Program_registry.run_fields), [] for no program. [Error] when the folder
    cannot be made. *)

val save_failure : Run_record.t -> unit
(** The frame now, in the session, as the run's failure.png; a refusal (an older
    daemon) is skipped. *)

val finish :
  runs_dir:string -> Run_record.run -> line:string -> code:int -> unit
(** The run's ending: a pass for exit code 0, else a failure with [line]. *)
