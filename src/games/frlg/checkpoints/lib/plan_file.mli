(** Reads a FireRed checkpoint plan file: the JSON, its fragment calls expanded
    ({!Frlg_fragments.Fragment_calls}), then its place routes
    ({!Frlg_places.Place_targets}), decoded by {!Checkpoints.Plan_decode}. Every
    FireRed plan is loaded through it. *)

val decode :
  source:string -> Yojson.Safe.t -> (Checkpoints.Plan.t, string) result
(** The plan in the JSON, expanded; [source] names it in errors. *)

val load : string -> (Checkpoints.Plan.t, string) result
(** The plan in the file at the path, named by its base name in errors. *)
