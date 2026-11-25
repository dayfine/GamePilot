(** Where a checkpoint declares the player ends, for the end check after its
    last event (the runner's [end_at], as a [Pose.Grid]).

    Checkpoints chain: each one ends where the next one starts, which is what
    lets the checkpoint runner save a passing end as the next start. So the
    declared end is the next checkpoint's [start] when there is one; for the
    last checkpoint it is its last event's grid [declared_after], else that
    event's route or ready target. A plan whose postconditions name a [position]
    ({!Pokemon_rules.Postconditions.t}) ends there instead, as the C++'s
    [check_postconditions()] prefers it
    ([Pokemon/AutoStory/Pokemon_StoryPostconditionCheck.cpp], fork [frlg/lean]);
    the caller picks it. The rest of the postconditions are
    {!Pokemon_rules.Postcondition_check}'s. *)

open Pokemon_checkpoints

val declared :
  next:Plan.checkpoint option ->
  Plan.checkpoint ->
  Pokemon_rules.Pose.grid option
(** [None] when neither the next checkpoint nor the last event names a grid
    pose. *)
