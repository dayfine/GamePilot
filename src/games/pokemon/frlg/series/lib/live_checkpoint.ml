(* What one live run of a checkpoint is given (Checkpoint_live_run): the
   series' setup, the checkpoint, and how the run ended. *)

open Engine_run
open Pokemon_engine

type setup = {
  states : string;
  runs_dir : string;
  backend : Daemon_process.backend;
  common : Plan_command.flags;
  mode : Checkpoint_trials.mode;
  policy : Checkpoint_trials.policy;
  world : Frlg_overworld.Frlg_steps.world;
  save_after_pass : bool;
      (** On the Switch: save in the game after a pass
          (Checkpoints_series.Console_runs). *)
  close_game : bool;
      (** On the Switch: return to HOME and close the running game after a
          passing series ([--close-game]). *)
  home_tile : Switch.Home_screen.tile_color option;
  info : Run_record.info;  (** For each run's run.json. *)
  program_options : Run_options.t;
      (** --options, checked: for each run's game actions. *)
  daemons : Series_daemons.t;
      (** Each run's daemon: the daemon, its recording and keep-awake flags as
          the user gave them (the daemon's defaults otherwise: on for the
          Switch, off for mGBA), the program's port and the watch page; the next
          run's daemon asks for the ports the last one bound, so the page keeps
          its URL across runs. *)
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

(* A failure the shared runner reports (Live_run.Daemon_run). *)
let failed ({ at; reason; repeats } : Daemon_run.failed) =
  Failed { at; reason; repeats }

let trial = function
  | Passed _ -> Checkpoint_trials.Passed
  | Failed { at; repeats; _ } -> Checkpoint_trials.Failed { at; repeats }

let of_failure (f : Failure.t) =
  Failed
    {
      at = Printf.sprintf "#%d %s" (f.event_index + 1) f.event_id;
      reason = Failure.reason_to_string f.reason;
      repeats = Failure.repeats f;
    }

(* A partial run's events, [None] for a whole run. *)
let partial_range cp =
  Option.map
    (fun (p : Frlg_checkpoints.Checkpoint_run.from_event) -> p.range)
    cp.partial

(* A partial run's first and last event, as run.json gives them. *)
let events cp =
  Option.map
    (fun range ->
      Engine_run.Event_range.describe range
        (List.map (fun (e : Plan.event) -> e.id) cp.plan.checkpoint.events))
    (partial_range cp)
