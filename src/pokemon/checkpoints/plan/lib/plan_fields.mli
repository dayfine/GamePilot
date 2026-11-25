(** The field readers {!Plan_decode} and {!Postcondition_decode} share. Every
    reader takes [where], the prefix of the object's fields
    (["f: checkpoint."]), as {!Grid_maps.Json_field} does. *)

val known_fields_only :
  where:string -> string list -> Grid_maps.Json_field.obj -> unit
(** Fails on a field not in the list. *)

val required : where:string -> string -> Grid_maps.Json_field.obj -> unit

val object_field :
  where:string -> string -> Grid_maps.Json_field.obj -> Grid_maps.Json_field.obj

val optional :
  where:string ->
  string ->
  Grid_maps.Json_field.obj ->
  (where:string -> string -> Grid_maps.Json_field.obj -> 'a) ->
  'a option
(** The field read when it is there. *)

val grid_pose : where:string -> Grid_maps.Json_field.obj -> Pose.grid
val item : where:string -> Grid_maps.Json_field.obj -> Plan.item
