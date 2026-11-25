(** Where a plan says the player stands, and where a game reports them.

    A plan's pose ({!grid}) names a map and, optionally, the tiles the player
    may be on and the way they face: several tiles are alternatives, no tiles is
    any tile of the map, and no facing is any facing. A game without tiles
    declares a {!zone} instead. *)

type grid = {
  map : string;
  tiles : Grid_maps.Tile_pos.t list;
  facing : Grid_maps.Direction.t option;
}

type zone = { place : string; spot : string option; heading : int option }
(** A place in a game with no tile grid; [heading] in degrees. *)

(** A [start] or [declared_after]: a tile pose or a zone one. *)
type declared = Grid of grid | Zone of zone

type observed = {
  at_map : string;
  at_tile : Grid_maps.Tile_pos.t;
  faces : Grid_maps.Direction.t option;  (** [None] when the game cannot tell. *)
}
(** Where a game reads the player to be. *)

val grid_matches : grid -> observed -> bool
(** The map is the pose's, the tile one of its tiles (any, when it lists none),
    and the facing its facing when both the pose and the reading know it. *)

val grid_to_string : grid -> string
(** ["CeladonCity (48, 12) south"]; alternatives joined by ["|"]. *)

val observed_to_string : observed -> string
(** ["CeladonCity (48, 12) south"], or without the facing when unknown. *)

val declared_to_string : declared -> string
(** A grid pose as {!grid_to_string}, a zone as ["zone <place>"]. *)

val observed_to_json : observed -> Yojson.Safe.t
(** [{"map": "CeladonCity", "tile": [48, 12], "facing": "south"}], the facing
    [null] when unknown. *)

val observed_of_json : Yojson.Safe.t -> (observed, string) result
(** What {!observed_to_json} wrote: ["not a map and a tile"] or
    ["not an object"] else. *)
