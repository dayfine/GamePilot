let read path =
  let name = Filename.basename path in
  match Yojson.Safe.from_file path with
  | json -> Ok json
  | exception Yojson.Json_error message -> Error (name ^ ": " ^ message)
  | exception Sys_error message -> Error message
