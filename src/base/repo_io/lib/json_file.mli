(** Reading and writing a JSON file as a [Result]: the one place data readers
    and writers catch [Sys_error] and [Yojson.Json_error], which the Yojson file
    functions raise. *)

val read : string -> (Yojson.Safe.t, string) result
(** The JSON in the file at the path; an error names the file by its base name.
*)

val write : string -> Yojson.Safe.t -> (unit, string) result
(** The JSON written to the file at the path; an error says why it was not. *)
