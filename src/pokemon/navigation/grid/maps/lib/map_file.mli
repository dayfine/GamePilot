(** Reading maps from PokemonSimulation's map files.

    A game's maps live in one directory, [data/games/<game>/maps] in
    PokemonSimulation: [base/] (generated from the decompilation), [overlays/]
    (authored fixes) and [runtime/] (base and overlays at the end of the story:
    the files consumers read). A map file is a [pokesim-runtime-map/1] or [/2]
    JSON object (see {!Runtime_format}); only ["name"], ["source"] and ["tiles"]
    are required. *)

val parse : source_name:string -> Yojson.Safe.t -> (Map_data.t, string) result
(** The map, or an error naming [source_name], the JSON path and what is wrong
    with it (["Maps/TestTown.json: warps[2].x is missing."]): a field missing or
    of the wrong type, something placed outside the tiles, or a gate or switch
    that does not fit them ({!Map_checks}). *)

val of_string : source_name:string -> string -> (Map_data.t, string) result
(** {!parse} on JSON text; malformed JSON is an error too. *)

val load : string -> (Map_data.t, string) result
(** The map in a file, named in errors by its path. *)

val runtime_path : maps_dir:string -> string -> string
(** [maps_dir/runtime/<name>.json]: where the runtime file of map [name] is. *)

val runtime_names : maps_dir:string -> string list
(** The names of the maps in [maps_dir/runtime], sorted. Raises [Sys_error] if
    there is no such directory. *)

val load_runtime : maps_dir:string -> string -> (Map_data.t, string) result
(** {!load} on {!runtime_path}. *)
