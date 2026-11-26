(** plza.autostory's checkpoints on the Switch
    (Plza_checkpoint_series.Checkpoint_series), each attempt through
    Plza_autostory.Story_game and the engine: a plan's start signature is
    checked before it (Plza_autostory.Start_signature) and its end after. The
    series' first run starts where the console is, put there by hand (01.00b on
    the new game's Confirm Choices, 01.01 on the platform); every later run of
    the same checkpoint first goes back to the latest autosave
    (Plza_autostory.Game_reload), which 01.00b cannot (its start is no save):
    its second run is refused. Its daemons keep the console awake with the right
    stick (Plza_checkpoint_series.Checkpoint_series.keepawake_stick), and each
    checkpoint wakes the screen before it reads it (Plza_story.Screen_wake).
    Every plan is checked (Plza_autostory.Plan_check) before the console moves.
*)

val run_series :
  program:(string * string) list ->
  options:Run_options.t ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series ~program ~options ~viewport plan_dir args]:
    {!Plza_checkpoint_series.Checkpoint_series.run_series} with the story's
    attempts; [program] is run.json's program fields. *)
