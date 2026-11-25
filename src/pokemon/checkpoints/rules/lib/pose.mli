(** Where a plan says the player stands, and where a game reports them.

    A plan's pose ({!grid}) names a map and, optionally, the tiles the player
    may be on and the way they face: several tiles are alternatives, no tiles is
    any tile of the map, and no facing is any facing. A game without tiles
    declares a {!zone} instead. *)

type grid = {
  map : string;
  tiles : Grid_geometry.Tile_pos.t list;
  facing : Grid_geometry.Direction.t option;
}

type zone = { place : string; spot : string option; heading : int option }
(** A place in a game with no tile grid; [heading] in degrees. *)

(** A [start] or [declared_after]: a tile pose or a zone one. *)
type declared = Grid of grid | Zone of zone

type observed = {
  at_map : string;
  at_tile : Grid_geometry.Tile_pos.t;
  faces : Grid_geometry.Direction.t option;
      (** [None] when the game cannot tell. *)
}
(** Where a game reads the player to be. *)

val grid_matches : grid -> observed -> bool
(** The map is the pose's, the tile one of its tiles (any, when it lists none),
    and the facing its facing when both the pose and the reading know it. *)
