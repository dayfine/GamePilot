(** Where a plan says the player stands, and where a game reports them.

    A plan's pose ({!grid}) names a map and, optionally, the tiles the player
    may be on and the way they face: several tiles are alternatives, no tiles is
    any tile of the map, and no facing is any facing. A game without tiles
    declares a {!zone} instead. A checkpoint's start may instead be a class of
    places ({!place_class}): anywhere the story allows, not the tile the plan's
    author stood on. *)

type grid = {
  map : string;
  tiles : Grid_geometry.Tile_pos.t list;
  facing : Grid_geometry.Direction.t option;
}

type zone = { place : string; spot : string option; heading : int option }
(** A place in a game with no tile grid; [heading] in degrees. *)

(** A class of places a checkpoint may start anywhere in. Each game recognises
    it its own way. *)
type place_class =
  | Outdoors
      (** Outdoors, where the game lets the player fly: a town, a city or a
          route (FireRed: the map types that allow Fly, pret pokefirered
          src/overworld.c). *)

(** A [start] or [declared_after]: a tile pose or a zone one; a start may also
    be [Anywhere] in a class of places. *)
type declared = Grid of grid | Zone of zone | Anywhere of place_class

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

val grid_to_string : grid -> string
(** ["CeladonCity (48, 12) south"]; alternatives joined by ["|"]. *)

val observed_to_string : observed -> string
(** ["CeladonCity (48, 12) south"], or without the facing when unknown. *)

val place_class_name : place_class -> string
(** The class as a plan writes it: ["outdoors"]. *)

val place_class_of_name : string -> place_class option
(** The class a plan names, if it is one. *)

val place_class_text : place_class -> string
(** The class in words: ["anywhere outdoors where Fly works"]. *)

val to_string : declared -> string
(** A grid pose as {!grid_to_string}, a zone as ["zone <place>"], a class as
    ["anywhere outdoors"]. *)
