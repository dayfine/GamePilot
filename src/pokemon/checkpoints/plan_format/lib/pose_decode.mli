(** Reads a plan's poses ({!Pose}): a grid pose (a route's target, the
    postconditions' position), a [declared_after], which is a grid pose or a
    zone, and a [start], which may also be a class of places. Every reader takes
    [where], the prefix of the object's fields (["f: checkpoint.start."]), and
    raises {!Json_field.Invalid} as {!Json_field}'s readers do. *)

open Pokemon_rules

val grid_pose : where:string -> Json_field.obj -> Pose.grid
(** [{"map": ..., "tiles": [[x, y], ...], "facing": ...}]; [tiles] and [facing]
    may be left out. *)

val declared : where:string -> Json_field.obj -> Pose.declared
(** A grid pose (it has a ["map"]) or a zone (a ["place"]), not both or neither.
*)

val start : where:string -> Json_field.obj -> Pose.declared
(** A {!declared} pose, or [{"anywhere": "outdoors"}]: a class of places
    ({!Pose.place_class}). *)
