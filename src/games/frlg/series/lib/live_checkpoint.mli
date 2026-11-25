(** What one live run of a checkpoint is given (Checkpoint_live_run): the
    series' setup, the checkpoint, and how the run ended. *)

open Engine_run
open Pokemon_checkpoints

type setup = {
  states : string;
  runs_dir : string;
  daemon : string;
  backend : Daemon_process.backend;
  common : Checkpoint_command.flags;
  mode : Checkpoint_trials.mode;
  policy : Checkpoint_trials.policy;
  world : Frlg_overworld.Frlg_steps.world;
  watch : Daemon_process.watch option;  (** the daemon's watch page, if any *)
  save_after_pass : bool;
      (** On the Switch: save in the game after a pass
          (Checkpoints_series.Console_runs). *)
  info : Run_record.info;  (** For each run's run.json. *)
  daemon_flags : string list;
      (** The daemon's recording and keep-awake flags, as the user gave them
          (the daemon's defaults otherwise: on for the Switch, off for mGBA). *)
  bound : (int * int option) option ref;
      (** The ports the series' last daemon bound (program, page): the next one
          asks for them again, so the page keeps its URL across runs. *)
  from_event : (string * string option) option;
      (** --from-event and --to-event: a partial run (Engine_run.Event_range).
      *)
  max_rounds : int option;
      (** --max-rounds: a repeating checkpoint's rounds, in place of its plan's
          (testing a few rounds). *)
}

type checkpoint = {
  id : string;  (** The plan file's name, e.g. ["mg-04"]. *)
  plan : Plan.t;
  end_at : Pose.grid option;
  start_state : string;
      (** The save state it starts from on mGBA; on the Switch, the save the
          console has loaded. *)
  before : Postconditions.t option;
      (** What the checkpoint before it promised, if any: the start check's
          party. *)
  next_id : string option;  (** The checkpoint after it, if any. *)
  partial : Frlg_checkpoints.Checkpoint_run.from_event option;
      (** A partial run's events; [start_state] is then its first event's kept
          state. *)
}

type outcome =
  | Passed of { goal : bool option }
      (** [goal]: whether a repeating checkpoint's goal holds after the run;
          [None] for a checkpoint that does not repeat. *)
  | Failed of { at : string; reason : string; repeats : bool }

val failed : Daemon_run.failed -> outcome
(** A failure the shared runner reports (Live_run.Daemon_run). *)

val trial : outcome -> Checkpoint_trials.run
(** The outcome as the trials policy counts it. *)

val of_failure : Failure.t -> outcome
(** A failed event: at ["#N event_id"], its reason, whether it repeats. *)

val partial_range : checkpoint -> Event_range.t option
(** A partial run's events, [None] for a whole run. *)

val events : checkpoint -> (string * string) option
(** A partial run's first and last event, as run.json gives them. *)
