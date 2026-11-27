let read path =
  let name = Filename.basename path in
  match Yojson.Safe.from_file path with
  | json -> Ok json
  | exception Yojson.Json_error message -> Error (name ^ ": " ^ message)
  | exception Sys_error message -> Error message

let of_string text =
  match Yojson.Safe.from_string text with
  | json -> Ok json
  | exception Yojson.Json_error message -> Error ("invalid JSON: " ^ message)

let write path json =
  match Yojson.Safe.to_file path json with
  | () -> Ok ()
  | exception Sys_error message -> Error message
