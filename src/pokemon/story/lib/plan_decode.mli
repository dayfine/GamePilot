(** Reads a checkpoint plan file ([pokesim-authored-checkpoint/1]) into a
    {!Plan.t}.

    It is as strict as PokemonSimulation's reader on the record: unknown fields,
    kinds and built-in args, missing required fields, malformed poses and
    repeated event ids are errors, each naming the file and the field, as in
    ["mg-01.plan.json: checkpoint.events[1].args.target.map is missing."]. It
    does not check a game action's args (the game does, when it binds the
    action) nor the game's [execution] settings. *)

val format : string
(** ["pokesim-authored-checkpoint/1"]. *)

val decode : source:string -> Yojson.Safe.t -> (Plan.t, string) result
(** The plan in the JSON; [source] names it in errors (the file name). *)

val load : string -> (Plan.t, string) result
(** The plan in the file at the path, named by its base name in errors. *)
