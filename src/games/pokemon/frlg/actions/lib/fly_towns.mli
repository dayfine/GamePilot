(** Kanto's Fly destinations: each town's cell on the fly map and the tile Fly
    lands the player on, read from
    [src/games/pokemon/frlg/assets/kanto_fly_towns.json] (made from pokefirered,
    as its ["source"] says). *)

type town = {
  name : string;  (** The map's name, as a plan names it (["CeladonCity"]). *)
  cell : Grid_geometry.Tile_pos.t;
      (** Presses right and down from the map's top-left corner. *)
  landing : Pokemon_engine.Pose.observed;
      (** Facing south, as every Fly lands the player; a walk from it needs no
          turn tap first, which would be a step when the player already faces
          the leg's way. *)
}

type t = {
  columns : int;  (** Cells across the fly map. *)
  rows : int;  (** Cells down. *)
  towns : town list;  (** Pallet Town first. *)
}

val asset : string
(** The table's path from the repo root. *)

val parse : Yojson.Safe.t -> (t, string) result

val load : unit -> (t, string) result
(** The table, found from the working directory ({!Repo_io.Repo_files.locate})
    and read once. *)

val find : t -> string -> town option

val cursor_presses : town -> Wire.command list
(** On the fly map: up-left held to the corner, then taps right and down to the
    town's cell. *)
