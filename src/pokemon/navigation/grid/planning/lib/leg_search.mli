(** The leg planner's search: Dijkstra over where the player is, which way they
    face, and how the leg they are in could end. A leg that ends where the
    player could keep going costs {!Leg_costs.t.per_open_stop} and the model's
    risks; one that ends against a wall costs nothing extra. {!Leg_planner}
    turns the presses found into legs. *)

type 'state found = {
  moves : (Direction.t * 'state Leg.step) list;
      (** The presses from the start, in order, and what each did. *)
  end_state : 'state;
  end_facing : Direction.t option;
      (** [None] only when the start is the goal and its facing is not known. *)
}

val run :
  'state Step_model.t ->
  Leg_costs.t ->
  start:'state ->
  start_facing:Direction.t option ->
  at_goal:('state -> bool) ->
  goal_facing:Direction.t option ->
  'state found option
(** The presses to the goal state cheapest to end at (stopping there, then
    turning to [goal_facing] if given), or [None] if no goal can be reached. Of
    equally cheap ways, the one found first wins: presses are tried north, east,
    south, west. *)
