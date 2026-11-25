(** The places table (src/games/frlg/places/places.json): named spots a plan
    walks to instead of writing a map and tile (Programs-As-Goals section 3).

    A place is a map, the tile to stand on and the way to face there, and the
    object it is for, named by its id in PokemonSimulation's runtime map
    (third_party/PokemonSimulation/data/games/frlg/maps/runtime), or in a
    standard Pokemon Center's coded room ([Frlg_overworld.Standard_center]): its
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
  stand : Grid_maps.Tile_pos.t;  (** The tile to stand on to use the object. *)
  facing : Grid_maps.Direction.t;  (** The way to face there. *)
  map_object : map_object;
}
(** One named spot of the table. *)

type t
(** The loaded table: its places by name, in the file's order, and its towns. *)

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

val towns : t -> Towns.t
(** The table's [towns] section. *)

val find : t -> string -> (place, string) result
(** The place of that name; an unknown name's error suggests the nearest. *)

val spot : place -> Checkpoints_expand.Place_routes.spot
(** Where a route to the place ends: its map, its stand tile, its facing. *)

val routes : t -> Checkpoints_expand.Place_routes.game
(** FireRed's answers to the place expansion: the table's places, and the lift
    rides ({!Lift_stops.ride}). *)

val resolve : t -> Engine_expand.Fragment_calls.resolve
(** FireRed's answers to a fragment's placeholders: a ["town"] parameter's key,
    nurse, Fly name or mart ({!Towns.field}). *)
