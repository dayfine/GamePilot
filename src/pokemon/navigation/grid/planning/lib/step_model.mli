(** A game's step model: what pressing a direction once does, for the leg
    planner ({!Leg_planner}) to search over. The game decides what a press does;
    the planner searches, joins steps into legs, and weighs where legs end. *)

type 'state t = {
  compare_state : 'state -> 'state -> int;
      (** A total order on states, for the search's sets. *)
  press : 'state -> Direction.t -> 'state Leg.step option;
      (** What pressing the direction once does, or [None] if the player can't
          go that way (a wall, or something the plan must not do). *)
  held_at : 'state -> Direction.t -> bool;
      (** Whether holding the direction keeps the player on this state: a wall,
          but not a person who may walk off or an edge to a map that isn't
          loaded. *)
  open_stop_risk : ('state -> Direction.t -> int) option;
      (** The extra cost of a leg that ends on the state walking that way where
          the player could keep going: what a tile past the stop would cost,
          e.g. a tile a trainer may see. *)
  tap_stop_risk : ('state -> Direction.t -> int option) option;
      (** For such a leg of one step from where a hold to a wall ended, the
          extra cost to weigh instead of [open_stop_risk] and
          {!Leg_costs.t.per_open_wild_stop}, or [None] to weigh those. A step
          can't stop part-way, so where an interruption stopping it would leave
          the player is no guess: on open water, a hold to a wall and a tile on
          starts a leg down a column with no wall of its own. *)
  open_check_risk :
    ('state -> Direction.t -> run:int -> next:Direction.t option -> int) option;
      (** The extra cost of an open leg [run] tiles long (counted up to
          {!max_counted_run}) followed by a leg [next] ([None]: the walk ends
          there), when the walk can't tell from that leg where the open one
          ended and has to find the player at walls. *)
}

val max_counted_run : int
(** How far {!t.open_check_risk}'s [run] counts: 3. Longer legs count as 3. *)

val simple :
  compare_state:('state -> 'state -> int) ->
  press:('state -> Direction.t -> 'state Leg.step option) ->
  held_at:('state -> Direction.t -> bool) ->
  'state t
(** A model that weighs no risks of its own. *)
