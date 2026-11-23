(** The checkpoint runner's rules for running one checkpoint several times from
    its start state: how many runs, how many must pass, when to stop early, and
    whether a passing end is kept as the next checkpoint's start.

    Ported from the fork's [frlg/lean] (paths under
    [SerialPrograms/Source/Pokemon/AutoStory/Engine/]):
    - modes are [CheckpointTestingStatus] ([Pokemon_StorySavePolicy.h]): testing
      saves nothing ([StorySaveMode::NONE]), verification saves after verifying
      ([AFTER_VERIFICATION]). Reproduction ([PER_CHECKPOINT]) is not ported yet.
    - the verification policy is [VerifyModePolicy{runs = 3, passes_needed = 2}]
      and its loop [verify_checkpoint()] ([Pokemon_StoryVerifyRuns.{h,cpp}]):
      every run goes from the same start, a failure that repeats stops the loop.
    - the hard stop "the same step fails twice in a row" is the
      console-iteration skill's (section 9); the C++ does not enforce it.

    Where it differs: [verify_checkpoint()] saves the end only when every run
    passed; here a verified checkpoint (2 of 3) keeps its last passing run's
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
