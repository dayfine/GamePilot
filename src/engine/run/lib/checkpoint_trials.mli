(** The checkpoint runner's rules for running one checkpoint several times from
    its start state: how many runs, how many must pass, when to stop early, and
    whether a passing end is kept as the next checkpoint's start.

    Ported from the fork's [frlg/lean] (paths under
    [SerialPrograms/Source/Pokemon/AutoStory/Engine/]):
    - the modes come from [Pokemon_StorySavePolicy.h]: testing saves nothing,
      verification saves after verifying. Its third mode, reproduction (a save
      after every checkpoint), is not ported yet.
    - the verification policy (3 runs, 2 passes needed) and its loop come from
      [Pokemon_StoryVerifyRuns.{h,cpp}]: every run goes from the same start, a
      failure that repeats stops the loop.
    - the hard stop: when the same step fails twice in a row, stop the loop and
      diagnose before another run. The C++ does not enforce it.

    Where it differs: the C++ verification loop saves the end only when every
    run passed; here a verified checkpoint (2 of 3) keeps its last passing run's
    end, as the user's save policy ("verification saves after 2-3 passes") says.
    Testing runs one run by default and needs one pass. *)

type mode = Testing | Verification

val mode_of_string : string -> mode option
(** ["testing"] or ["verification"]. *)

val mode_to_string : mode -> string

type policy = {
  runs : int;  (** Runs of the checkpoint, each from its start state. *)
  passes_needed : int;
  keeps_end : bool;
      (** A passing run's end is saved as the next checkpoint's start once the
          checkpoint passes (verification only). *)
}

val policy : ?runs:int -> mode -> (policy, string) result
(** Testing: [runs] (default 1), one must pass. Verification: [runs] (default
    3), two must pass. An error when [runs] is below 1 or below the passes
    needed. *)

(** How one run ended. *)
type run =
  | Passed
  | Failed of { at : string; repeats : bool }
      (** [at] names where it failed (["#3 talk_clerk"], or the handler's error
          for a run that broke off); [repeats]: another run would fail the same
          way. *)

type verdict =
  | Run_again
  | Checkpoint_passed of { passes : int; runs : int }
  | Stopped of string  (** Why the checkpoint did not pass. *)

val verdict : policy -> run list -> verdict
(** The verdict after these runs (oldest first): stopped when the last two
    failed at the same step or the last one repeats, passed or stopped once
    every run ran, else run again. *)

val until_decided :
  policy ->
  trial:('r -> run) ->
  (int -> ('r, string) result) ->
  verdict * 'r list
(** Runs [n] = 1, 2, ... until the {!verdict} is no longer [Run_again]: the
    verdict and the runs, oldest first. [trial] reads a run's outcome. A run
    that could not happen ([Error], e.g. no folder for its record) stops the
    checkpoint with that error, the runs before it kept. *)

(** {1 Attempts within a run}

    A run whose plan allows retries (the plan's [retries],
    {!Engine_plan.Plan.Make.t}) is up to [retries + 1] attempts, each from the
    checkpoint's start (mGBA reloads the start state; the Switch goes back to
    its last save and checks the start, as every run does). The run passes when
    an attempt passes, all postconditions holding; verification counts the run
    once, its attempts inside it. For a checkpoint whose outcome depends on
    battle luck (mg-05: Knock Off on the partner). Not in the fork, whose
    verification loop ([Pokemon_StoryVerifyRuns.cpp]) has no retries. *)

type attempt = Attempt_passed | Attempt_failed of failure

and failure = {
  at : string;  (** Where it failed, as {!run}'s [at]. *)
  reason : string;  (** Why, e.g. ["mail_glitch_not_active: ..."]. *)
  repeats : bool;  (** Another attempt would fail the same way. *)
}

type attempt_verdict =
  | Attempt_again
  | Run_passed
  | Run_failed of { at : string; repeats : bool; why : string }
      (** [repeats]: the run's failure is not luck, so verification stops: the
          last attempt's failure repeats, or every attempt (more than one)
          failed at the same step for the same reason. *)

val attempts : retries:int -> attempt list -> attempt_verdict
(** The run's verdict after these attempts (oldest first): passed at the first
    pass, failed at once on a failure that repeats or when [retries + 1]
    attempts failed, else another attempt. *)
