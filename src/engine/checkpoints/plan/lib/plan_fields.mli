(** The field readers a plan's decoders share, the engine's ({!Plan_decode}) and
    a game's (its poses, kinds and promises). Every reader takes [where], the
    prefix of the object's fields (["f: checkpoint."]), as {!Json_field} does,
    and raises {!Json_field.Invalid} as its readers do. *)

val known_fields_only : where:string -> string list -> Json_field.obj -> unit
(** Fails on a field not in the list. *)

val required : where:string -> string -> Json_field.obj -> unit
(** Fails when the field is missing. *)

val object_field : where:string -> string -> Json_field.obj -> Json_field.obj
(** The object field; fails when it is missing or not an object. *)

val optional :
  where:string ->
  string ->
  Json_field.obj ->
  (where:string -> string -> Json_field.obj -> 'a) ->
  'a option
(** The field read when it is there. *)
