(** Kanto's Fly destinations: each town's cell on the fly map and the tile Fly
    lands the player on. Ported from the fork's Overworld/PokemonFRLG_FlyMap:
    cells are pokefirered's sRegionMapSections_Kanto (the cursor's x and y),
    landing tiles its heal locations. Pure. *)

type town = {
  name : string;  (** The map's name, as a plan names it (["CeladonCity"]). *)
  cell : Grid_maps.Tile_pos.t;
      (** Presses right and down from the map's top-left corner. *)
  landing : Story.Pose.observed;  (** Facing unknown. *)
}

val columns : int
(** 22 cells across (MAP_WIDTH in region_map.c). *)

val rows : int
(** 15 cells down. *)

val kanto : town list
(** Pallet Town first. *)

val find : string -> town option

val cursor_presses : town -> Wire.command list
(** On the fly map: up-left held to the corner, then taps right and down to the
    town's cell. *)
