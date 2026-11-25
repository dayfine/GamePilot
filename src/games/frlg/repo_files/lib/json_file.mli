(** Reading a JSON file as a [Result]: the one place a file's [Sys_error] and
    [Yojson.Json_error] are caught for the FireRed data readers. *)

val read : string -> (Yojson.Safe.t, string) result
(** The JSON in the file at the path; an error names the file by its base name.
*)
