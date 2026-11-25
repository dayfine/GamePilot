(** The places table (src/games/frlg/places/places.json): named spots a plan
    walks to instead of writing a map and tile (Programs-As-Goals section 3).

    A place is a map, the tile to stand on and the way to face there, and the
    object it is for, named by its id in PokemonSimulation's runtime map
    (third_party/PokemonSimulation/data/games/frlg/maps/runtime): its
    coordinates stay there and are never copied here. A spot with no object in
    those maps (a save spot, or an object the maps lack) says so with
    [not_in_maps], and gives the object's tile when it has one. *)

(** What a place is for, by its id in the map. *)
type map_object =
  | Npc of string  (** An npc by its [source_script]. *)
  | Item of string  (** An item ball by its [source_script]. *)
  | Hidden_item of string  (** A hidden item by its [flag]. *)
  | Warp of { warp : string; to_map : string }
      (** A door: the map's warp ["warp_<n>"] (the [n]th of its [warps], as pret
          numbers them), leading to [to_map]. *)
  | Not_in_maps of { what : string; tile : Grid_maps.Tile_pos.t option }
      (** Not in the maps: what it is, and the object's tile if it has one. *)

type place = {
  name : string;
  map : string;
  stand : Grid_maps.Tile_pos.t;
  facing : Grid_maps.Direction.t;
  map_object : map_object;
}

type t

val format : string
(** ["gamepilot-places/1"]. *)

val asset : string
(** The table's path from the repo root. *)

val parse : source:string -> Yojson.Safe.t -> (t, string) result
(** The table in the JSON; errors name [source] and the field. *)

val load : unit -> (t, string) result
(** The table in {!asset}, read once. *)

val places : t -> place list
(** In the file's order. *)

val find : t -> string -> (place, string) result
(** The place of that name; an unknown name's error suggests the nearest. *)

val pose : place -> Checkpoints.Pose.grid
(** Where a route to the place ends: its map, its stand tile, its facing. *)
