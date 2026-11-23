(** Steps and legs: what one press does, and a walk as straight runs ("hold east
    for 4 tiles, then south"). A game's step model ({!Step_model}) says what a
    press does; {!Leg_planner} searches over presses and joins them into legs
    with {!join}. *)

type action = ..
(** A step of a game's own kind (starting to Surf, opening a gate), planned as a
    leg on its own. Games and planner wrappers add their constructors. *)

type 'state step = {
  next : 'state;
  action : action option;  (** [None] for a plain step. *)
  starts_leg : bool;
      (** The step can't continue the leg before it, e.g. leaving the water,
          after which the player walks at another speed. *)
  ends_leg : bool;
      (** No later step continues this leg: the game stops the player, e.g. at a
          warp. *)
  warped : bool;  (** The step takes a warp: a door, a ladder, a cave mouth. *)
  facing : Direction.t;
      (** Which way the player faces afterwards. Usually the pressed direction;
          some warps turn the player. *)
  extra_cost : int;
      (** Cost on top of {!Leg_costs.t.per_tile}: tall grass, a warp's fade, a
          dialog. *)
  wild : bool;
      (** The walk can be interrupted on this step, e.g. by a wild battle in
          tall grass. See {!Leg_costs.t.per_open_wild_stop}. *)
  connection : bool;
      (** The step crosses a map connection without warping. See
          {!Leg_costs.t.per_open_connection_stop}. *)
}
(** What one press does. *)

val plain_step : 'state -> Direction.t -> 'state step
(** A plain step to [next], facing the pressed direction, with nothing else set:
    the base a model's steps are built from. *)

(** What a leg does. *)
type kind =
  | Walk of { tiles : int; to_wall : bool }
      (** Hold the direction for [tiles] steps. [to_wall]: holding on keeps the
          player on the last tile, so the leg can be held for longer than it
          takes and walked again after an interruption. *)
  | Action of action  (** One step of the game's own kind. *)
  | Face  (** Turn to the direction without moving. *)

type 'state t = {
  kind : kind;
  direction : Direction.t;
  warps : bool;  (** The last step takes a warp. *)
  wild : bool;  (** A step of the leg is wild ({!step.wild}). *)
  facing_after : Direction.t;
  start : 'state;
  finish : 'state;
}
(** One straight run, one action, or a turn on the spot. *)

val join :
  held_at:('state -> Direction.t -> bool) ->
  'state ->
  (Direction.t * 'state step) list ->
  'state t list
(** The legs of a walk from a state, given as the presses made and what each
    did: consecutive plain steps the same way join, unless a step starts a new
    leg or the one before ended its leg. [held_at] says whether holding a
    direction keeps the player on a state (see {!Step_model.t.held_at}). *)

val face : 'state -> Direction.t -> 'state t
(** A leg that turns to a direction on a state. *)
