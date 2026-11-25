(** The floors a lift stops at, by map, and the ride a walk to a place on
    another floor takes ({!Checkpoints_expand.Place_routes.game}'s [ride]): the
    floors and their exits are {!Frlg_actions.Lift_ride}'s, and the ride is its
    ["lift_floor"] action. *)

type stop = {
  lift : Frlg_actions.Lift_ride.lift;
  floor : string;  (** As the lift's panel names it: ["4F"]. *)
  map : string;
  door : Checkpoints_expand.Place_routes.spot;
      (** Below the floor's lift door, facing it: where a ride starts. *)
  exit : Checkpoints_expand.Place_routes.spot;
      (** Where a ride to this floor lets the player out (the same tile, facing
          south). *)
}
(** One floor a lift stops at. *)

val of_map : string -> stop option
(** The lift stop on that map, if a lift stops there. *)

val way_out : Frlg_actions.Lift_ride.lift -> stop
(** The floor a walk to anywhere off the lift's floors leaves from: the store's
    1F, the hideout's B1F (its stairs up to the Game Corner). *)

val ride :
  at:Checkpoints_expand.Place_routes.spot ->
  Checkpoints_expand.Place_routes.spot ->
  (Checkpoints_expand.Place_routes.ride option, string) result
(** The lift ride a walk from [at] to the spot takes: between their floors when
    both are on one lift, down to {!way_out} when leaving the lift's floors, up
    from it when arriving; none when the floors are the same or neither is on a
    lift. A walk between two lifts is an error. *)
