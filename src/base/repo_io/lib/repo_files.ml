let locate path =
  let rec up dir =
    let candidate = Filename.concat dir path in
    if Sys.file_exists candidate then Some candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else up parent
  in
  up (Sys.getcwd ())

let home_dir () =
  match Sys.getenv_opt "HOME" with
  | Some h when h <> "" -> h
  | _ -> (
      match Sys.getenv_opt "USERPROFILE" with
      | Some h when h <> "" -> h
      | _ -> ".")

let data_dir var name =
  match Sys.getenv_opt var with
  | Some dir when dir <> "" -> dir
  | _ ->
      List.fold_left Filename.concat (home_dir ())
        [ ".local"; "share"; "gamepilot"; name ]
