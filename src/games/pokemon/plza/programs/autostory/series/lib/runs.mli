(** plza.autostory's checkpoints on the Switch
    (Plza_checkpoint_series.Checkpoint_series), each attempt through
    Plza_autostory.Story_game and the engine: a plan's start signature is
    checked before it (Plza_autostory.Start_signature), and its end place (its
    postconditions' [place], else the next checkpoint's start signature, put in
    its postconditions as the series loads it) is the runner's: a checkpoint
    already there runs no event, and every other one must end there. The series'
    first run starts where the console is, put there by hand (01.01 on the new
    game's Confirm Choices, 01.02 on the platform); every later run of the same
    checkpoint first goes back to the latest autosave
    (Plza_autostory.Game_reload), which 01.01 cannot (its start is no save): its
    second run is refused. Its daemons keep the console awake with the right
    stick (keepawake_stick), and each checkpoint wakes the screen before it
    reads it (Plza_story.Screen_wake). Every plan is checked before the console
    moves ({!Series_check.check_all}). *)

val run_series :
  program:(string * string) list ->
  options:Run_options.t ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series ~program ~options ~viewport plan_dir args]:
    {!Plza_checkpoint_series.Checkpoint_series.run_series} with the story's
    attempts; [program] is run.json's program fields, [options] the program's
    options, checked (Program_registry.check_options), for run.json and
    00.00-new-game's choices ({!Plza_autostory.New_game_options.of_run_options},
    over the plan's args; {!Series_check} refuses before the console moves
    choices it cannot play). *)
