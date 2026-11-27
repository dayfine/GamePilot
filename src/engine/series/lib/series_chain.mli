(** Chaining state across a series of checkpoints, trials, rounds and attempts.

    A series starts cold (not continuing from a pass). Once a checkpoint or
    round passes, the next one continues directly from that pass. A run is
    already at its start only on the first trial and first attempt when
    continuing directly from a pass; cold starts, retries ([attempt > 1]), and
    later trials ([trial > 1]) are not. *)

type 'a item = {
  value : 'a;  (** The checkpoint being run (its id or plan). *)
  next : 'a option;
      (** The next checkpoint in the series, or [after] for the last. *)
  continuing_from_pass : bool;
      (** [true] when the immediately preceding checkpoint in the series passed.
      *)
}
(** Position of one checkpoint in a series. *)

type trial = {
  number : int;  (** Trial number, starting at 1. *)
  continuing_from_pass : bool;
      (** [true] when the checkpoint or round continues directly from a passing
          checkpoint or round. *)
}
(** Context for one trial of a checkpoint. *)

val already_at_start :
  continuing_from_pass:bool -> trial:int -> attempt:int -> bool
(** [already_at_start ~continuing_from_pass ~trial ~attempt] is [true] only when
    [continuing_from_pass] holds and [trial = 1] and [attempt = 1]. Cold starts,
    retries ([attempt > 1]), and later trials ([trial > 1]) return [false]. *)

val trial_already_at_start : trial -> attempt:int -> bool
(** [trial_already_at_start t ~attempt] is {!already_at_start} for trial [t] and
    [attempt]. *)

val run_chain : ?after:'a -> 'a list -> ('a item -> bool) -> bool
(** [run_chain ?after items f] runs [f] on each item of [items] in order,
    stopping at the first item for which [f] returns [false]. The first item
    starts with [continuing_from_pass = false]; each subsequent item starts with
    [continuing_from_pass = true]. Each item's [next] is the following element
    of [items], or [after] for the last item. Returns [true] when every item
    passed (including an empty list), [false] when one stopped. *)

val run_trials :
  Engine_run.Checkpoint_trials.policy ->
  continuing_from_pass:bool ->
  trial:('r -> Engine_run.Checkpoint_trials.run) ->
  (trial -> ('r, string) result) ->
  Engine_run.Checkpoint_trials.verdict * 'r list
(** [run_trials policy ~continuing_from_pass ~trial run] runs trials [1, 2, ...]
    through {!Engine_run.Checkpoint_trials.until_decided}, passing each trial's
    {!trial} context to [run]. *)

val run_attempts :
  retries:int ->
  trial ->
  attempt:('r -> Engine_run.Checkpoint_trials.attempt) ->
  (attempt:int -> already_at_start:bool -> ('r, string) result) ->
  (int * 'r * Engine_run.Checkpoint_trials.attempt_verdict, string) result
(** [run_attempts ~retries t ~attempt run] runs attempts [1, 2, ...] of trial
    [t] until {!Engine_run.Checkpoint_trials.attempts} decides. Each attempt
    receives its 1-based [attempt] number and
    [already_at_start = trial_already_at_start t ~attempt]. Returns
    [Ok (attempts, last, verdict)] on decision, or [Error e] when an attempt
    could not start. *)

val round_trial : continuing_from_pass:bool -> trial
(** A repeating checkpoint's round trial context: [number = 1] with
    [continuing_from_pass], so the first attempt of a round continuing from a
    passing checkpoint or previous passing round is already at start, while
    retries ([attempt > 1]) are not. *)

val run_rounds :
  max_rounds:int ->
  capped:bool ->
  continuing_from_pass:bool ->
  round:('r -> Round_trials.round) ->
  next_state:('s -> 'r -> 's) ->
  's ->
  ('s -> number:int -> trial -> ('r, string) result) ->
  Round_trials.decision * 'r list
(** [run_rounds ~max_rounds ~capped ~continuing_from_pass ~round ~next_state
     init run] runs rounds of a repeating checkpoint until
    {!Round_trials.decide} stops or meets its goal. Each round receives the
    current state (updated by [next_state]), its 1-based round [number], and its
    {!round_trial} context; an [Error e] from [run] stops with
    [Round_trials.Stopped e]. Returns the final decision and all completed
    rounds, oldest first. *)

val verdict_outcome :
  ?note:string ->
  id:string ->
  Engine_run.Checkpoint_trials.verdict ->
  bool * string option
(** [verdict_outcome ?note ~id verdict] turns a checkpoint's trial verdict into
    [(passed, line)], where [line] is the [[Checkpoints]] summary line for
    [Checkpoint_passed] (with optional trailing [note]) or [Stopped], and [None]
    for [Run_again]. *)
