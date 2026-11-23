(** A leg of a robust plan ({!Robust_planner}): walk a direction for so many
    tiles, or until stopped, and every place the player may stand on after. *)

type 'state t = {
  direction : Direction.t;
  tiles : int;  (** Tiles travelled; a ledge hop counts 2. *)
  to_wall : bool;  (** Walked until the player is stopped. *)
  after : 'state list;
      (** Every place the player may stand on once the leg is done. *)
  held : bool;
      (** An open leg held for its tiles' time instead of tapped a tile at a
          time ({!Robust_costs.t.hold_open_legs}). A held leg is never joined
          with the next one the same way: each is its own hold. *)
}

val joins : 'state t -> 'state t -> bool
(** Whether the second leg walks on as one hold with the first: both open and
    tapped, the same way. *)

val consolidate : 'state t list -> 'state t list
(** The legs with each open leg joined to the next one the same way ({!joins}):
    they are one hold. *)
