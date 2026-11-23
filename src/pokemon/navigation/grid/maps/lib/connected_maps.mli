(** The one world the tile games (BDSP, FRLG) plan and walk on: maps joined by
    their warps and their edges ({!Map_data.t.connections}). The player's place
    in it is a map and a tile of that map, in the map's own coordinates. Where a
    warp or an edge leads is the same in both games; whether a step is allowed,
    and what the game does on arrival, is each game's. *)

type place = { map : int; tile : Tile_pos.t }
(** A tile of one of the connected maps: the map's index (see {!map}) and the
    tile in that map's own coordinates. *)

val compare_place : place -> place -> int
(** Map, then tile: an order for sets and maps of places. *)

type t

val create : Map_data.t list -> t
(** The maps, indexed in list order. *)

val size : t -> int
(** How many maps there are: indexes run from 0 to [size - 1]. *)

val map : t -> int -> Map_data.t
(** The map at an index. Raises [Invalid_argument] past the last map, as for a
    place from another world. *)

val find : t -> string -> int option
(** The index of the map with that name. *)

val warp_arrival : t -> Map_features.warp -> place option
(** Where taking a warp puts the player: its destination point. [None] if it
    leads to a map that is not here, or names a point that map lacks. *)

val across_edge : t -> place -> Direction.t -> place option
(** The tile past that side of the place's map that carries on its row or
    column: on the first map connected on that side that has it. *)

val neighbour : t -> place -> Direction.t -> place option
(** The tile next to a place in a direction: on the same map, or across its
    edge. [None] past an edge that leads nowhere here. Raises [Invalid_argument]
    for a place whose map index is past the last. *)

val connect_by_world : Map_data.t list -> Map_data.t list
(** Joins the maps that lie on the same world grid ({!Map_data.t.world}) where
    they meet: each map gets a connection on each side to every map whose
    rectangle touches that side, unless it has one to that map already. Maps
    without a world are left as they are. *)
