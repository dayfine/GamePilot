(** The selected checkpoints in order, each run until its policy decides
    (Engine_run.Checkpoint_trials), stopping at the first that does not pass; a
    repeating checkpoint round by round. Ported from the fork's run over a
    checkpoint range and its verification loop
    (Pokemon/AutoStory/Engine/Pokemon_StoryEngine.cpp and
    Pokemon_StoryVerifyRuns.cpp, frlg/lean; see Run_command). *)

val run :
  plan_dir:string ->
  Checkpoint_live_run.setup ->
  string list ->
  after:string option ->
  int
(** The checkpoints [ids] of the folder, [after] the id after the last (its plan
    declares the last one's end); the exit code. *)
