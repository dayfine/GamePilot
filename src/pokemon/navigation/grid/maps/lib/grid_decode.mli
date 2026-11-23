(** Reading a map file's tile rows and elevation rows. Both raise
    {!Json_field.Invalid} naming [where] (the file, as ["Test.json: "]). *)

val tiles : where:string -> Json_field.obj -> Tile_kind.t Grid.t
(** ["tiles"]: non-empty rows of tile glyphs, all as wide as the first. *)

val elevation :
  where:string -> width:int -> height:int -> Json_field.obj -> int Grid.t option
(** ["elevation"], the tiles' size: one lowercase hex digit (0 to 15) per tile.
    [None] when the map leaves it out; what the levels mean is the game's
    business (FRLG reads a map without them as all ground, 3). *)
