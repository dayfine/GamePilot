(** Plans walks whose open legs may go a tile short or long. A leg to a wall is
    walked until the player stops; an open leg is walked for its tiles' worth of
    time and may end a few tiles either way. The planner searches (Dijkstra)
    over the sets of places the player may stand on after each leg, and later
    walls bring them back together, so the plan reaches the goal from every
    place the player may be.

    The model ({!Robust_model}) and the leg planner's
    ({!Grid_planning.Step_model}) describe the same world rules for two
    planners; {!Robust_model.of_step_model} turns one into the other. *)

val plan :
  ?costs:Robust_costs.t ->
  'state Robust_model.t ->
  from:'state list ->
  at_goal:('state -> bool) ->
  'state Robust_leg.t list option
(** The cheapest legs that take the player from any of [from] to places that all
    satisfy [at_goal], even if every open leg ends up to its error off, with
    open legs the same way joined ({!Robust_leg.consolidate}). Legs that run
    along where someone wanders are not used unless
    {!Robust_costs.t.forbid_along_wander} is off. [None] if no such plan exists,
    or none is found within {!Robust_costs.t.max_searched} sets. [costs]
    defaults to {!Robust_costs.default}. *)

val cost :
  ?costs:Robust_costs.t ->
  'state Robust_model.t ->
  from:'state list ->
  'state Robust_leg.t list ->
  int
(** What {!plan} charges for walking the legs from any of [from], each leg from
    the places the one before may end on ({!Robust_leg.t.after}). A leg it would
    not plan costs its tiles and legs without wild or wander tiles. *)
