(** Reads a FireRed checkpoint plan file: the JSON, its fragment calls expanded
    ({!Engine_expand.Fragment_calls}, with the fragments of
    src/games/frlg/fragments/fragments.json and the places table's towns:
    {!Frlg_places.Place_table.resolve}), then its place routes expanded
    ({!Checkpoints_expand.Place_routes}, with FireRed's places and lifts:
    {!Frlg_places.Place_table.routes}), decoded by
    {!Checkpoints_plan.Plan_decode}. Every FireRed plan is loaded through it. *)

val decode :
  source:string -> Yojson.Safe.t -> (Checkpoints_plan.Plan.t, string) result
(** The plan in the JSON, its fragment calls and place routes expanded; [source]
    names it in errors. *)

val load : string -> (Checkpoints_plan.Plan.t, string) result
(** The plan in the file at the path, named by its base name in errors. *)
