(** Reads a plan's poses ({!Pose}): a grid pose (a route's target, the
    postconditions' position) and a [start] or [declared_after], which is a grid
    pose or a zone. Every reader takes [where], the prefix of the object's
    fields (["f: checkpoint.start."]), and raises {!Json_field.Invalid} as
    {!Json_field}'s readers do. *)

val grid_pose : where:string -> Json_field.obj -> Pose.grid
(** [{"map": ..., "tiles": [[x, y], ...], "facing": ...}]; [tiles] and [facing]
    may be left out. *)

val declared : where:string -> Json_field.obj -> Pose.declared
(** A grid pose (it has a ["map"]) or a zone (a ["place"]), not both or neither.
*)
