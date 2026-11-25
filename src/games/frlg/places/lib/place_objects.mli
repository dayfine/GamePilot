(** A place's object found in PokemonSimulation's runtime map, so a test can
    check that every place still points at something there and stands where it
    can use it. *)

val maps_dir : string
(** The runtime maps' folder from the repo root. *)

val load_map : string -> (Yojson.Safe.t, string) result
(** The runtime map file of that name, as JSON. *)

val tile :
  Yojson.Safe.t ->
  Place_table.map_object ->
  (Grid_maps.Tile_pos.t option, string) result
(** The object's tile in the map's JSON: the one npc or item with that
    [source_script], the hidden item with that [flag], the warp of that index
    (checking that it leads to [to_map]); a [not_in_maps] object's own tile, or
    [None] when it has none. An error says what is missing or ambiguous. *)

val check : Yojson.Safe.t -> Place_table.place -> (unit, string) result
(** The place's object is in the map and usable from the stand tile: a door next
    to it; anything else straight ahead in its facing, one tile away or two
    (across a counter). *)
