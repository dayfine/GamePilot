(** One leg ({!Scored_leg}) walked from one tile, nothing interrupting: the
    tiles it surely walks, where it may end, and how long it takes. *)

type t = {
  path : Tile_pos.t list;
      (** Tiles surely walked, in order, the first after the start. *)
  ends : Tile_pos.t list;  (** Where the leg may end. *)
  ms : int;
  stop : bool;  (** Ended at a wall (a re-localization). *)
  unsafe : string option;
      (** Why the leg may end somewhere it must not: the first tile of a held
          open leg's uncertain end that is a hazard. *)
}

val to_wall : Score_map.t -> Route_paces.t -> Tile_pos.t -> Scored_leg.t -> t
(** A leg held until the player stops: on a wall, or on a warp or trigger, which
    is not a stop. Without its press overhead. *)

val walk :
  Score_map.t ->
  Route_paces.t ->
  goal:(Tile_pos.t -> bool) ->
  Tile_pos.t ->
  Scored_leg.t ->
  t
(** The leg as its kind walks it, with its press overhead. A held open leg's
    uncertain end may reach a warp or trigger only if [goal] accepts it. *)
