(** The checkpoint runner's rules for a repeating checkpoint ({!Plan.repeat}):
    after each round, run another, go on (the goal holds) or stop. A round is
    one run of the checkpoint, its attempts inside it
    ({!Checkpoint_trials.attempts}); each passing round is saved like any
    checkpoint, so a failed attempt goes back to the last round's save. The goal
    is read after each passing round.

    {!Repeat_until} is the same loop inside one session, with the game's own
    heal, save and reload as chores; this one decides between the series' runs
    (each with its own daemon), where the round's plan heals and the runner
    saves. GamePilot's own: the fork has no repeating checkpoint. *)

type round =
  | Round_passed of { goal_met : bool }
      (** The round passed; whether the goal held after it. *)
  | Round_failed of string
      (** Out of attempts, or failed in a way that repeats: why. *)

type decision =
  | Next_round of int  (** Run this round (from 1). *)
  | Goal_met of { rounds : int }
  | Capped of { rounds : int }
      (** Testing with a grind cap: [max_rounds] rounds ran, which passes; the
          goal is a full grind's. *)
  | Stopped of string  (** Why the checkpoint did not pass. *)

val decide : max_rounds:int -> capped:bool -> round list -> decision
(** The decision after these rounds (oldest first). *)

val decision_to_string : decision -> string
(** ["round 3"], ["goal met after 3 rounds"], ["capped after 2 rounds"],
    ["stopped: goal not met after 20 rounds"]. *)
