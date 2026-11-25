(** The selected checkpoints in order, each run until its policy decides
    (Engine_run.Checkpoint_trials), stopping at the first that does not pass; a
    repeating checkpoint round by round. StoryEngine::run_checkpoints() and
    verify_checkpoint() on the fork's frlg/lean (Checkpoints_command). *)

val run :
  plan_dir:string ->
  Checkpoint_live_run.setup ->
  string list ->
  after:string option ->
  int
(** The checkpoints [ids] of the folder, [after] the id after the last (its plan
    declares the last one's end); the exit code. *)
