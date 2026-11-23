(** The runtime map wire formats PokemonSimulation publishes, decoded to one.

    A map file is [pokesim-runtime-map/1] (also when it has no ["format"]:
    objects in one ["objects"] list with a ["kind"], positions as ["x"] and
    ["y"]) or [pokesim-runtime-map/2] (objects in typed lists ["npcs"],
    ["items"], ["signs"], ["interactables"], positions as ["coord": [x, y]],
    wander boxes as ["min"] and ["max"]). {!to_v1} turns either into the v1 form
    {!Map_data} reads, as PokemonSimulation's [legacy_map] does. *)

val to_v1 : where:string -> Yojson.Safe.t -> Yojson.Safe.t
(** The map in v1 form, without ["format"]. Fields the formats do not name are
    kept as they are. Objects come in the order npcs, items, signs,
    interactables (interactables get kind ["item"]), each group in file order. A
    v2 pickup (an item record with ["item"] or ["quantity"]) gets quantity 1
    when it has none and the name [item_<source_event>] when it has no name.

    Raises {!Json_field.Invalid}, naming [where] (the file, as ["Test.json: "])
    and the field, for an unknown format, a v1 map with v2 fields or the
    reverse, a malformed position, or a malformed pickup. *)
