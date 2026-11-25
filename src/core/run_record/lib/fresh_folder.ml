type made = Made | Taken

let dir_perm = 0o755
let failed path e = Error (path ^ ": " ^ Unix.error_message e)

let make path =
  match Unix.mkdir path dir_perm with
  | () -> Ok Made
  | exception Unix.Unix_error (Unix.EEXIST, _, _) -> Ok Taken
  | exception Unix.Unix_error (e, _, _) -> failed path e

let is_dir path =
  match Unix.stat path with
  | { st_kind = S_DIR; _ } -> true
  | _ -> false
  | exception Unix.Unix_error _ -> false

let rec make_all path =
  if is_dir path then Ok ()
  else
    let parent = Filename.dirname path in
    let parents = if parent = path then Ok () else make_all parent in
    Result.bind parents (fun () ->
        match make path with
        | Ok Made -> Ok ()
        | Ok Taken when is_dir path -> Ok ()
        | Ok Taken -> Error (path ^ ": not a folder")
        | Error e -> Error e)
