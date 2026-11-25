(** Reads a FireRed checkpoint plan file: the JSON, with its place routes
    expanded ({!Checkpoints_expand.Place_routes}, with FireRed's places and
    lifts: {!Frlg_places.Place_table.routes}), decoded by
    {!Checkpoints.Plan_decode}. Every FireRed plan is loaded through it. *)

val decode :
  source:string -> Yojson.Safe.t -> (Checkpoints.Plan.t, string) result
(** The plan in the JSON, its place routes expanded; [source] names it in
    errors. *)

val load : string -> (Checkpoints.Plan.t, string) result
(** The plan in the file at the path, named by its base name in errors. *)
