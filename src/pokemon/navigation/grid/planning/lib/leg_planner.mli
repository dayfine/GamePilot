(** Plans a walk as straight legs: hold one direction, then the next. The game
    decides what a single press does through its step model ({!Step_model}); the
    planner searches ({!Leg_search}), joins steps into legs ({!Leg.join}), and
    prefers legs that end against a wall, because the player stops there however
    long the button is held, while a leg that ends in the open depends on
    timing. It can weigh more heavily an open stop after tiles where the walk is
    likely to be interrupted (tall grass): after an interruption a leg to a wall
    is simply walked again, while how far an open one got is a guess. *)

val plan :
  ?costs:Leg_costs.t ->
  'state Step_model.t ->
  start:'state ->
  start_facing:Direction.t option ->
  at_goal:('state -> bool) ->
  goal_facing:Direction.t option ->
  'state Leg.t list option
(** The cheapest legs from [start] (facing [start_facing], if known) to a state
    where [at_goal] holds, ending with a {!Leg.Face} leg when the walk does not
    already end facing [goal_facing]; [None] if no goal can be reached. [costs]
    defaults to {!Leg_costs.default}. *)
