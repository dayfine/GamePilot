(** The rules a map holds beyond its JSON shape. Each raises
    {!Json_field.Invalid} naming [where] (the file, as ["Test.json: "]) and the
    record that breaks it. *)

val places_inside : where:string -> Map_data.t -> unit
(** Every point, region tile, warp, object, wander box, trigger box and patch
    lies inside the tiles. *)

val gates_fit : where:string -> Map_data.t -> unit
(** Every gate tile is a [Gate] tile inside the map, in one gate only, and every
    [Gate] tile is in a gate; a switch gate follows a switch the map lists; each
    switch's floors name this map; a statue is faced from a tile next to it, the
    way it says; a button is a [Strength_button] tile; a warp on a [Fall_hole]
    is one way. *)
