(** Reading the records of a v1 map file (see {!Runtime_format}) other than its
    tiles and gates. Each reader takes the top-level object and raises
    {!Json_field.Invalid} naming [where] (the file, as ["Test.json: "]) and the
    field. Lists and tables the map leaves out read as empty. *)

open Map_features

val source : where:string -> Json_field.obj -> source
(** Required. *)

val world : where:string -> Json_field.obj -> world option

val points : where:string -> Json_field.obj -> (string * Tile_pos.t) list
(** Named tiles: ["points": {"door": [1, 2]}]. *)

val regions : where:string -> Json_field.obj -> (string * Tile_pos.t list) list
(** Named non-empty lists of tiles, each in file order. *)

val flag_sets : where:string -> Json_field.obj -> (string * string list) list
(** Flags set together, by name (["after_hall_of_fame"]). *)

val warps : where:string -> Json_field.obj -> warp list
(** ["to_map"] and ["to_point"] come together or not at all; ["enter"] defaults
    to walking into the warp. *)

val objects : where:string -> Json_field.obj -> map_object list
(** A trainer's ["looks"] defaults to the object's facing; one without either is
    an error. *)

val triggers : where:string -> Json_field.obj -> trigger list
val connections : where:string -> Json_field.obj -> connection list
val patches : where:string -> Json_field.obj -> patch list
