(** [bdsp.static_rng]'s checkpoint series on the Switch
    ({!Bdsp_checkpoint_series.Checkpoint_series}), dispatching
    {!Bdsp_rules.Action.Save_game} and {!Bdsp_rules.Action.Static_rng} to
    {!Bdsp_static_rng.Static_rng.run_action}. *)

val run_series :
  program:(string * string) list ->
  options:Run_options.t ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series ~program ~options ~viewport plan_dir args]: runs
    [bdsp.static_rng]'s checkpoint series via
    {!Bdsp_checkpoint_series.Checkpoint_series.run_series}; [program] is
    [run.json]'s program fields. *)
