(** [bdsp.battle_catch]'s checkpoint series on the Switch
    ({!Bdsp_checkpoint_series.Checkpoint_series}), dispatching
    {!Bdsp_rules.Action.Save_game} and {!Bdsp_rules.Action.Battle_catch} to
    {!Bdsp_battle_catch.Battle_catch.run}. *)

val run_series :
  program:(string * string) list ->
  options:Run_options.t ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series ~program ~options ~viewport plan_dir args]: runs
    [bdsp.battle_catch]'s checkpoint series via
    {!Bdsp_checkpoint_series.Checkpoint_series.run_series}; [program] is
    [run.json]'s program fields. *)
