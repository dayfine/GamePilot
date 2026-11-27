(** Reading and writing a JSON file as a [Result], catching the [Sys_error] and
    [Yojson.Json_error] that the Yojson file functions raise. *)

val read : string -> (Yojson.Safe.t, string) result
(** The JSON in the file at the path; an error names the file by its base name.
*)

val of_string : string -> (Yojson.Safe.t, string) result
(** Parses a JSON string as a [Result], catching [Yojson.Json_error]. *)

val write : string -> Yojson.Safe.t -> (unit, string) result
(** The JSON written to the file at the path; an error says why it was not. *)
