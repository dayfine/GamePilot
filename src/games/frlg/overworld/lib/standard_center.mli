(** A Pokemon Center's ground floor in the shared layout, coded rather than
    mapped. 17 of FireRed's 19 [*_PokemonCenter_1F] maps use
    LAYOUT_POKEMON_CENTER_1F (pokefirered data/maps/*/map.json); the Indigo
    Plateau's and One Island's have their own layouts and are in
    PokemonSimulation's maps. Every standard Center gets this room, as the user
    decided ("regular pokemon center which we should script, like in C++"), so
    all 17 walk the same way. Its mat lets out on its town's door, and its
    people stand in the way, so routes and places reach into it as into any
    mapped room.

    Ported from the fork's [Overworld/PokemonFRLG_CodedRooms.{h,cpp}]
    ([CENTER_ROOM_JSON], [pokemon_center_room()], [add_pokemon_center_room()]),
    Overworld/PokemonFRLG_PokemonCenterRoom.h ([CENTER_MAT],
    [CENTER_NURSE_FRONT]) and Overworld/PokemonFRLG_OverworldMaps.cpp
    ([add_unmapped_centers()]): the same tiles, elevation, mat warps, door point
    and people.

    Where we differ:
    - The mat's warps follow each Center's own map.json order, so ["warp_<n>"]
      is pret's: Cinnabar's lists the middle tile first, and the Two to Seven
      Island Centers have the middle tile alone. The fork uses the mainland's
      order, (6..8, 8), for all.
    - Cinnabar's room has Bill at (11, 5), hidden by
      FLAG_HIDE_CINNABAR_POKECENTER_BILL. He waits there after a player turns
      him down, and the fork's story never meets him there.
    - Each Center has all its pret people ({!Center_people}), not the nurse
      alone. Each person has a pret script, for places to name, and the stairs
      lead to the town's 2F (not loaded).
    - The room is added only for the 17 standard Centers, where the fork's
      [is_pokemon_center()] takes any [_PokemonCenter_1F]. It replaces
      PokemonSimulation's map of a standard Center, where the fork adds it only
      for a Center with no map: {!Frlg_checkpoints.Checkpoint_run.load_world}
      does not read those map files.
    - There is a ["pc_front"] point, the PC's stand as
      [Frlg_checkpoints.Make_room] uses it. *)

open Grid_maps

val centers : string list
(** The 17 maps that use the shared layout, by name. *)

val is_standard : string -> bool
(** Whether the map is one of {!centers}. *)

val mat : Tile_pos.t
(** (7, 8): the mat's middle tile, where the player arrives from the door and
    leaves walking south. *)

val nurse_front : Tile_pos.t
(** (7, 4): below the counter, facing the nurse at (7, 2). *)

val pc_front : Tile_pos.t
(** (11, 2): below the PC, facing north. *)

val room :
  center:string ->
  outside:Map_features.warp_destination ->
  (Map_data.t, string) result
(** The coded ground floor of [center]. Its mat lets out on [outside] (the
    town's door point). Its points are each mat warp's ["warp_<n>"], ["mat"],
    ["nurse_front"] and ["pc_front"]. [Error] for a map not in {!centers}. *)

val with_rooms : Map_data.t list -> Map_data.t list
(** The maps, plus the room of each standard Center whose door is on one of them
    and that is not among them. As in the fork, each such town gets a point
    ["<Center>_door"] on that door, and only its first such Center is added. The
    caller leaves out the standard Centers' map files for their rooms to be
    added. *)
