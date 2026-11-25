(** The floors a lift stops at, by map, for routes to a place on another floor:
    the floors and their exits are {!Frlg_actions.Lift_ride}'s. *)

type stop = {
  lift : Frlg_actions.Lift_ride.lift;
  floor : string;  (** As the lift's panel names it: ["4F"]. *)
  map : string;
  door : Checkpoints.Pose.grid;
      (** Below the floor's lift door, facing it: where a ride starts (the
          lift's exit on that floor, facing north). *)
}

val of_map : string -> stop option
(** The lift stop on that map, if a lift stops there. *)

val way_out : Frlg_actions.Lift_ride.lift -> stop
(** The floor a walk to anywhere off the lift's floors leaves from: the store's
    1F, the hideout's B1F (its stairs up to the Game Corner). *)
