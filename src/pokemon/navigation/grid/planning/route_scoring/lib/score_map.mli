(** The grid a walk plan is scored on ({!Route_scorer}): where a step lands and
    what walking onto a tile risks. *)

(** What walking onto a tile risks. *)
type risk =
  | No_risk
  | Encounter  (** Tall grass: a wild battle may start. *)
  | Wanderer  (** Someone walking about may stand in the way. *)
  | Sight  (** A trainer sees the player and walks over. *)
  | Warp  (** A door or warp: walking onto it leaves the map. *)
  | Trigger  (** A scene starts here and stops the player. *)

type t = {
  step : Tile_pos.t -> Direction.t -> Tile_pos.t option;
      (** Where one step lands (a ledge hop lands two tiles on), or [None] if
          the player is stopped. A warp's tile is landed on. *)
  risk : Tile_pos.t -> risk;
}

val stops_on : risk -> bool
(** A warp or a trigger: the walk ends on the tile. *)

val walk_steps : t -> Tile_pos.t -> Direction.t -> most:int -> Tile_pos.t list
(** The tiles stepped onto from the tile that way, in order, until stopped, at
    most [most] steps; the walk ends on a warp or a trigger ({!stops_on}). *)
