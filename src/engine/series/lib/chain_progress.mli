(** What the watch page shows of a checkpoint chain
    ([gamepilot run --from --to]): each checkpoint's state and time, and the
    current one's trials, as the [watch.run] notification ({!Wire.Watch_run}).
    Pure: the caller gives the clock (Unix time in ms) and sends the result. The
    fork's AutoStory shows none of this; it is the watch page's own. *)

open Engine_run

type t

val create :
  mode:Checkpoint_trials.mode ->
  policy:Checkpoint_trials.policy ->
  started_ms:int ->
  string list ->
  t
(** The chain's checkpoint ids in run order, all pending. *)

val begin_checkpoint : t -> string -> now_ms:int -> t
(** The checkpoint starts: current, with no runs yet. *)

val begin_trial : t -> t
(** A run of the current checkpoint starts. *)

val end_trial : t -> Checkpoint_trials.run -> now_ms:int -> t
(** The run ended. The policy's verdict over the runs so far decides: the
    checkpoint passes, stays current for another run, or fails, and the
    checkpoints after it are skipped. *)

val begin_rounds : t -> max_rounds:int -> t
(** The current checkpoint repeats (the plan's [repeat]): each run is a round,
    shown as trial N of [max_rounds], and no run ends it; {!end_rounds} does. *)

val end_rounds : t -> passed:bool -> now_ms:int -> t
(** The rounds ended ({!Round_trials}): the checkpoint passed or failed. *)

val fail_checkpoint : t -> now_ms:int -> t
(** The current checkpoint could not run (its plan or start state is missing):
    failed, the rest skipped. *)

val to_wire : t -> now_ms:int -> Wire.Watch_run.t

val wire_progress :
  t -> now_ms:(unit -> int) -> Checkpoint_trials.run option -> Wire.Watch_run.t
(** [wire_progress started ~now_ms] builds the progress callback for a trial
    that started from [started]: [None] sends the in-progress chain, and
    [Some r] sends the chain with that trial ended by [r]. *)
