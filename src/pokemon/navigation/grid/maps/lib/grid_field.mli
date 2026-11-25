(** Reading a tile position or a direction from a map file's JSON, naming the
    field in errors as {!Json_field} does (and raising its [Invalid]). These
    readers were part of [Json_field] until it moved to [src/base], which may
    not name the grid's types. *)

val pos : where:string -> Json_field.obj -> Tile_pos.t
(** The fields ["x"] and ["y"]. *)

val pair : string -> Yojson.Safe.t -> Tile_pos.t
(** A value [[x, y]]; [where] names the value itself. *)

val direction_named : string -> string -> Direction.t
(** [direction_named where name]: the direction [name] names; raises naming
    [where] (the value itself) otherwise. *)

val direction : where:string -> string -> Json_field.obj -> Direction.t
(** The string field [key], read as a direction. *)
