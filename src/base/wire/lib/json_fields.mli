(** Reading fields out of decoded JSON. Every failure raises [Decode_error] with
    a message that names the field. In each function, the first argument [what]
    names the value being read (e.g. ["hello.result"]) for that message. *)

type json = Yojson.Safe.t
(** A decoded JSON value, as Yojson's [Safe] parser gives it. *)

exception Decode_error of string
(** JSON that is not what the reader expected: the message names the field (as
    [what.name]) and what was wrong with it. *)

val fail : ('a, unit, string, 'b) format4 -> 'a
(** [fail fmt ...] raises [Decode_error] with the formatted message. *)

val fields : string -> json -> (string * json) list
(** The members of an object; [what] names it in the error. *)

val field : string -> string -> json -> json
(** [field what name j]: member [name] of the object [j]; missing is an error.
*)

val field_opt : string -> string -> json -> json option
(** [field_opt what name j]: member [name] of the object [j], [None] when absent
    ([null] is returned as it is). *)

val to_int : string -> json -> int
(** An integer; a float with no fractional part counts as one. *)

val to_float : string -> json -> float
(** A number, integer or not. *)

val to_bool : string -> json -> bool
(** A boolean. *)

val to_string : string -> json -> string
(** A string. *)

val to_list : string -> json -> json list
(** A list's elements. *)

val int_field : string -> string -> json -> int
(** [int_field what name j]: {!field} then {!to_int}, the error naming
    [what.name]. *)

val float_field : string -> string -> json -> float
(** [float_field what name j]: {!field} then {!to_float}. *)

val string_field : string -> string -> json -> string
(** [string_field what name j]: {!field} then {!to_string}. *)

val list_field : string -> string -> json -> json list
(** [list_field what name j]: {!field} then {!to_list}. *)

val string_list_field : string -> string -> json -> string list
(** A list of strings, e.g. [probe_kinds]. *)

val json_of_strings : string list -> json
(** A JSON list of these strings, in order. *)

val parse_json : string -> json
(** Parses one JSON text; bad JSON is a [Decode_error] too. *)
