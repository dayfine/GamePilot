(** Plans legs ({!Leg_planner}) over maps with gates: the search state is the
    game's state and the gate state, so a plan may open a Card Key gate or press
    a statue on the way (see {!Gated_model}). *)

val plan :
  ?costs:Leg_costs.t ->
  'inner Gated_model.game ->
  Connected_maps.t ->
  Gated_model.rules ->
  start:'inner Gated_model.state ->
  start_facing:Direction.t option ->
  at_goal:('inner -> bool) ->
  goal_facing:Direction.t option ->
  'inner Gated_model.state Leg.t list option
(** The cheapest legs from [start] to a game state where [at_goal] holds, as
    {!Leg_planner.plan}. Each leg's start and finish carry the gate state;
    {!gate_change_of} says what an action leg did to it. *)

val gate_change_of : 'inner Gated_model.state Leg.t -> Gate_state.change
(** What a leg did to the gates: the gate it opened, the switch it flipped. *)

val gates_after :
  Gate_state.t -> 'inner Gated_model.state Leg.t list -> Gate_state.t
(** The gate state after the last leg, or the given one if there are none. *)
