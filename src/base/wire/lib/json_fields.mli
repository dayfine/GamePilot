(** Reading fields out of decoded JSON. Every failure raises [Decode_error] with
    a message that names the field. *)

type json = Yojson.Safe.t

exception Decode_error of string

val fail : ('a, unit, string, 'b) format4 -> 'a
(** [fail fmt ...] raises [Decode_error] with the formatted message. *)

val fields : string -> json -> (string * json) list
(** The members of an object; [what] names it in the error. *)

val field : string -> string -> json -> json
val field_opt : string -> string -> json -> json option
val to_int : string -> json -> int
val to_float : string -> json -> float
val to_string : string -> json -> string
val to_list : string -> json -> json list
val int_field : string -> string -> json -> int
val float_field : string -> string -> json -> float
val string_field : string -> string -> json -> string
val list_field : string -> string -> json -> json list

val string_list_field : string -> string -> json -> string list
(** A list of strings, e.g. [probe_kinds]. *)

val json_of_strings : string list -> json

val parse_json : string -> json
(** Parses one JSON text; bad JSON is a [Decode_error] too. *)

(** {1 Total readers}

    For results a reader reads every frame: [None] instead of [Decode_error]. *)

val member_opt : string -> json -> json option
(** An object's member; [None] for a missing one or a non-object. *)

val number_opt : json -> float option
(** An integer or a float. *)

val all_opt : ('a -> 'b option) -> 'a list -> 'b list option
(** [f] on every item; [None] as soon as one gives [None]. *)

val numbers_opt : json -> float list option
(** A list of numbers; [None] when any item is not one. *)
