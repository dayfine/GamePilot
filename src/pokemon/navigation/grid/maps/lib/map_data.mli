(** A map as a navigation program sees it: the tiles (with the console patches
    applied), the named points and regions routes start and end at, the warps,
    the objects standing on it, the scenes stepping somewhere starts, the edges
    joining it to other maps, and the gates the story opens. {!Map_file} reads
    one from PokemonSimulation's runtime map files; which game's planner reads
    it, and how, is the game's business. *)

module String_map : Map.S with type key = string
module String_set : Set.S with type elt = string

type t = {
  name : string;
  source : Map_features.source;
  world : Map_features.world option;
  allow_running : bool;
      (** Whether the game lets the player run here. FRLG's indoor maps, such as
          the Pokemon Centers, don't: B held there still walks. *)
  tiles : Tile_kind.t Grid.t;  (** With the patches applied. *)
  elevation : int Grid.t option;  (** The size of [tiles], when present. *)
  points : Tile_pos.t String_map.t;
  regions : Tile_pos.t list String_map.t;
      (** Named non-empty sets of tiles, in the order the map lists them. *)
  warps : Map_features.warp list;
  objects : Map_features.map_object list;
  triggers : Map_features.trigger list;
  flag_sets : String_set.t String_map.t;
      (** Flags set together, by name (["after_hall_of_fame"]). *)
  connections : Map_features.connection list;
  patches : Map_features.patch list;
  gates : Map_gates.gate String_map.t;
      (** By id. Every [Gate] tile of [tiles] is in exactly one gate. *)
  switches : Map_gates.switch String_map.t;
      (** By id: the switches this map's gates follow or that it has a statue or
          button of. *)
}

val warp_at : t -> Tile_pos.t -> Map_features.warp option
(** The warp on a tile, if there is one. *)

val default_max_tiles : int
(** How far {!tiles_to_door} looks when not told: 50 tiles. *)

val tiles_to_door :
  ?max_tiles:int -> Tile_kind.t Grid.t -> Tile_pos.t -> Direction.t -> int
(** The tiles walked from a tile in a direction up to and including the first
    [Door], [Wall] or [Outside] tile, stopping at the grid's edge and after
    [max_tiles]. Walkers bound a hold into a door by it. *)
