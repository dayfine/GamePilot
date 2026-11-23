(** Where a checkpoint declares the player ends, for the end check after its
    last event ({!Runner.run}'s [end_at]).

    Checkpoints chain: each one ends where the next one starts, which is what
    lets the checkpoint runner save a passing end as the next start. So the
    declared end is the next checkpoint's [start] when there is one; for the
    last checkpoint it is its last event's grid [declared_after], else that
    event's route or ready target. The C++ checks a plan's postconditions (map
    and tile) instead ([check_postconditions()] in
    [Pokemon/AutoStory/Pokemon_StoryPostconditionCheck.cpp], fork [frlg/lean]);
    the mail glitch plans state no postconditions, so the chain is the only end
    they declare. *)

val declared :
  next:Plan.checkpoint option -> Plan.checkpoint -> Pose.grid option
(** [None] when neither the next checkpoint nor the last event names a grid
    pose. *)
