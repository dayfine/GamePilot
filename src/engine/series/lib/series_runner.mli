(** Game-agnostic checkpoint series runner: runs a list of checkpoint entries in
    order ({!Series_chain.run_chain}), tracking watch-page chain progress
    ({!Chain_progress}), running each checkpoint's trials until the policy
    decides ({!Series_chain.run_trials}), logging the verdict summary
    ({!Series_chain.verdict_outcome}), and invoking the game's hooks.

    Games plug in a small {!hooks} record supplying only what varies per game:
    how an entry is prepared into a runnable checkpoint, how one trial runs
    (including any game-specific retries or reloads), how a run maps to
    {!Engine_run.Checkpoint_trials.run}, and what runs after a checkpoint
    passes. *)

type progress = Engine_run.Checkpoint_trials.run option -> Wire.Watch_run.t
(** Snapshot of the chain's watch progress before a trial ([None]) or after it
    ([Some run]). *)

type ('entry, 'plan, 'run) hooks = {
  entry_id : 'entry -> string;
      (** The checkpoint id of an entry, used for chain progress and logs. *)
  prepare : 'entry -> next:'entry option -> ('plan, string) result;
      (** Prepares an entry for execution given the entry after it in the series
          (if any). Returning [Error reason] logs the error, marks the
          checkpoint failed on the chain, and stops the series. *)
  run_trial :
    'plan -> Series_chain.trial -> progress:progress -> ('run, string) result;
      (** Runs one trial of a prepared checkpoint, receiving its trial context
          and a [progress] snapshot builder for the watch page. Returning
          [Error reason] marks the checkpoint failed on the chain and stops the
          checkpoint's trials. *)
  trial_of : 'run -> Engine_run.Checkpoint_trials.run;
      (** What the trial policy sees of a completed run. *)
  verdict_note : 'plan -> string;
      (** Optional trailing note appended to the passing verdict line (e.g. a
          grind cap note); [""] when none. *)
  on_pass : 'plan -> next:'entry option -> 'run list -> unit;
      (** Called once after a checkpoint passes its policy, with the runs
          executed (oldest first) and the next entry in the series. *)
}
(** Game-specific hooks plugged into {!run}. *)

val run :
  mode:Engine_run.Checkpoint_trials.mode ->
  policy:Engine_run.Checkpoint_trials.policy ->
  now_ms:(unit -> int) ->
  log:(string -> unit) ->
  ?after:'entry ->
  ?override:
    (chain:Chain_progress.t ref ->
    run_trial:('plan -> Series_chain.trial -> ('run, string) result) ->
    'plan ->
    continuing_from_pass:bool ->
    next:'entry option ->
    bool option) ->
  ('entry, 'plan, 'run) hooks ->
  'entry list ->
  bool
(** [run ~mode ~policy ~now_ms ~log ?after ?override hooks entries] runs
    [entries] in order until all pass or one fails, returning [true] when every
    entry passed. [after] is the entry following the last element of [entries]
    (passed as [~next] for the last checkpoint). When [override] is provided and
    returns [Some passed] for a prepared checkpoint, it runs in place of the
    standard trial policy loop (used by repeating checkpoints). *)

val run_testing :
  policy:Engine_run.Checkpoint_trials.policy ->
  now_ms:(unit -> int) ->
  log:(string -> unit) ->
  entry_id:('plan -> string) ->
  run_trial:('plan -> Series_chain.trial -> ('run, string) result) ->
  trial_of:('run -> Engine_run.Checkpoint_trials.run) ->
  'plan list ->
  bool
(** Convenience wrapper over {!run} for testing-mode series whose plans are
    already prepared and need no per-checkpoint verdict note or [on_pass] hook.
*)
