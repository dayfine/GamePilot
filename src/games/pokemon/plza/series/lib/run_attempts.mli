(** One run of a PLZA checkpoint as attempts, each after the first from the
    latest autosave: when to reload and try again, and how the run ends.

    Off its start: an attempt that fails because the console is not at the
    checkpoint's start ([chain_off_start], from the start signature or an
    action's own start check) and did not begin with a reload is followed by one
    that does, whose start is checked again. A checkpoint with no [start]
    (01.01, made by hand) has no autosave to go back to, and one off its start
    after a reload stays off it: both fail at once, as a failure that repeats.
    Where it differs: the fork's chain stops on [chain_off_start]
    (PokemonLZA_AutoStoryGame.cpp); here a checkpoint left off its start by a
    stopped run, or by the checkpoint before it, gets the reload a person would
    give it, and the log says so.

    Then the plan's [retries] (the engine's
    {!Engine_run.Checkpoint_trials.attempts}): a failure that does not repeat
    reloads and tries again, up to [retries + 1] attempts not counting the one
    after an off-start. As the fork's engine (Pokemon_StoryEngine.cpp), which
    reloads a failed checkpoint that started from a save up to its attempts per
    checkpoint (3 by default, PokemonLZA_AutoStory.cpp). Where it differs: the
    fork tries every checkpoint 3 times; here only a plan that names [retries]
    (a luck-bound step), so other failures stop for a look. *)

type failure = {
  at : string;  (** Where it failed: ["start"], ["#1 to_the_center"]. *)
  reason : string;
  repeats : bool;
      (** Another attempt from the same screen fails the same way. *)
  off_start : bool;  (** The console was not at the checkpoint's start. *)
}
(** A failed attempt. *)

(** How a run, or one attempt, ended. *)
type outcome =
  | Passed  (** The checkpoint's events all passed. *)
  | Failed of failure  (** Where and why it failed. *)

val off_start : Engine_run.Failure.cause -> bool
(** [chain_off_start], from a start check. *)

val of_cause : at:string -> Engine_run.Failure.cause -> outcome
(** A failure at [at] for this cause (["code: detail"]), off its start by
    {!off_start}. *)

val of_failure : Plza_engine.Failure.t -> outcome
(** The runner's failure at ["#<n> <event>"], off its start when its handler's
    cause is. *)

val trial : outcome -> Engine_run.Checkpoint_trials.run
(** What the series' policy sees of a run. *)

val run :
  has_start:bool ->
  retries:int ->
  reload_first:bool ->
  log:(string -> unit) ->
  (attempt:int -> reload:bool -> outcome) ->
  outcome
(** [run ~has_start ~retries ~reload_first ~log attempt]: attempts 1, 2, ...
    until one passes or the run fails; [reload] for every attempt but the first,
    and for the first when [reload_first]. Each reload's reason goes to [log]. A
    run that failed after more than one attempt says why in its reason
    (["failed on all 3 attempts: ..."]). *)
