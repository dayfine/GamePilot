(** Reading a data table's JSON (places, fragments) as [Result]s, each error
    naming the field: ["places.json: places.a.stand is not [x, y]."]. Every
    reader takes [where], the prefix the field name follows. *)

val error : string -> ('a, unit, string, ('b, string) result) format4 -> 'a
(** [error where fmt ...]: an [Error] of [where] and the formatted message. *)

val all_ok : ('a, 'e) result list -> ('a list, 'e) result
(** Every value, in order, or the first error. *)

val field :
  string -> string -> Plan_json.fields -> (Yojson.Safe.t, string) result
(** [field where key fields]: the field, or ["<key> is missing."]. *)

val string : string -> string -> Plan_json.fields -> (string, string) result
(** The string field, or why there is none. *)

val as_object :
  string -> string -> Yojson.Safe.t -> (Plan_json.fields, string) result
(** [as_object where key value]: the value's fields, or
    ["<key> is not an object."]. *)

val as_list :
  string -> string -> Yojson.Safe.t -> (Yojson.Safe.t list, string) result
(** The value's items, or ["<key> is not an array."]. *)

val as_string : string -> string -> Yojson.Safe.t -> (string, string) result
(** The value's string, or ["<key> is not a string."]. *)

val known_fields_only :
  string -> string list -> Plan_json.fields -> (unit, string) result
(** [known_fields_only where allowed fields]: [Ok] when every field is one of
    [allowed]; otherwise ["<key> is not a known field."] for the first that is
    not. *)
