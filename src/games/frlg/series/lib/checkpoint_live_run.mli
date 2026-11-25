(** One run of one checkpoint on the live emulator or the Switch: a run folder,
    a daemon logging to it, the checkpoint from its start state through
    Frlg_checkpoints.Checkpoint_run with its declared end, then the saves the
    outcome asks for while the session is still open, and the run's summary,
    KEEP and RESULTS.tsv row. A Stop pressed on the watch page is a failure
    ("stopped by user") that repeats, so the series stops too. *)

include module type of struct
  include Live_checkpoint
end

val capped_note : setup -> checkpoint -> string
(** With --grind-battles: the run line's note of the grind cap and the
    postconditions it skipped; [""] otherwise. *)

val run :
  setup ->
  checkpoint ->
  int ->
  attempt:int ->
  progress:(Engine_run.Checkpoint_trials.run option -> Wire.Watch_run.t) ->
  (Run_record.t * outcome, string) result
(** Attempt [attempt] of run [n] of the checkpoint: its folder and how it ended;
    [Error] when its folder could not be made. [progress] is the chain for the
    watch page before the attempt ([None]) and after it. *)
