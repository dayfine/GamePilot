(** Reading typed fields of a JSON object, naming the field in errors.

    Every reader takes [where], the file and the path to the object being read,
    written as a prefix the field name follows: ["Test.json: "] for the top
    level, ["Test.json: warps[2]."] inside a list item. A field that is missing
    or of the wrong type raises {!Invalid} with a message such as
    ["Test.json: warps[2].x is missing."]. A caller's decoder turns it into an
    [Error] (the grid's map reader does). Readers of grid types are in
    [Grid_maps.Grid_field]. *)

exception Invalid of string

type obj = (string * Yojson.Safe.t) list
(** A JSON object's fields, in file order. *)

val fail : ('a, unit, string, 'b) format4 -> 'a
(** Raises {!Invalid} with the formatted message. *)

val item_where : string -> string -> int -> string
(** [item_where where key i] is the prefix for item [i] of list [key]:
    ["<where><key>[<i>]."]. *)

val as_object : string -> Yojson.Safe.t -> obj
(** The value's fields; raises if it is not an object ([where] names the value
    itself). *)

val find : string -> obj -> Yojson.Safe.t option
(** The field, or [None] when the object leaves it out. *)

val has : string -> obj -> bool

val field : where:string -> string -> obj -> Yojson.Safe.t
(** The field; raises if it is missing. *)

val int : where:string -> string -> obj -> int
val string : where:string -> string -> obj -> string
val string_opt : where:string -> string -> obj -> string option

val bool_or : where:string -> default:bool -> string -> obj -> bool
(** The boolean field, or [default] when it is left out. *)

val list_opt : where:string -> string -> obj -> Yojson.Safe.t list option
(** The array field, or [None] when it is left out. *)

val object_opt : where:string -> string -> obj -> obj option
(** The object field, or [None] when it is left out. *)

val entries : where:string -> string -> obj -> (string * Yojson.Safe.t) list
(** The fields of the object field [key], or [[]] when it is left out. *)

val records :
  where:string -> string -> obj -> (where:string -> obj -> 'a) -> 'a list
(** Each object of the array field [key] read by the function, which gets the
    item's prefix; [[]] when the field is left out. *)

val strings : string -> Yojson.Safe.t -> string list
(** An array of strings; [where] names the array itself. *)
