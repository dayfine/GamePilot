(** A leg out of a spread (the places the player may stand on): where every
    place of it ends, and what the leg costs ({!Robust_costs}). *)

type 'state t = {
  cost : int;
  leg : 'state Robust_leg.t;
      (** Its [after] lists each place's ends in the spread's order. *)
  unsafe : bool;
      (** A held leg that may end somewhere a tap would not have reached (a wild
          or wander place, a ledge hop past its shortest end): not to be used,
          though a longer one may be. *)
}

val to_wall :
  'state Robust_model.t ->
  Robust_costs.t ->
  'state list ->
  Direction.t ->
  'state t option
(** Every place walks that way until stopped. [None] unless each is held and one
    moves, or if a walk runs along where someone wanders and
    {!Robust_costs.t.forbid_along_wander} is set. *)

val open_leg :
  'state Robust_model.t ->
  Robust_costs.t ->
  'state list ->
  Direction.t ->
  int ->
  'state t option
(** About that many tiles that way, give or take {!Robust_costs.open_leg_error}.
    [None] if any possible end is stopped where the player is not held, or runs
    along where someone wanders (when forbidden). *)
