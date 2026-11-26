let locate_in ~roots path =
  List.find_map
    (fun root ->
      let candidate = Filename.concat root path in
      if Sys.file_exists candidate then Some candidate else None)
    roots

let share_roots () =
  let env_root =
    match Sys.getenv_opt "GAMEPILOT_SHARE" with
    | Some dir when dir <> "" -> [ dir ]
    | _ -> []
  in
  let exe_dir = Filename.dirname Sys.executable_name in
  let share_under base =
    List.fold_left Filename.concat base [ "share"; "gamepilot" ]
  in
  env_root @ [ share_under exe_dir; share_under (Filename.dirname exe_dir) ]

let locate path =
  let rec up dir =
    let candidate = Filename.concat dir path in
    if Sys.file_exists candidate then Some candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else up parent
  in
  match up (Sys.getcwd ()) with
  | Some _ as found -> found
  | None -> locate_in ~roots:(share_roots ()) path

let daemon_basename =
  if Sys.win32 then "gamepilot_daemon.exe" else "gamepilot_daemon"

let default_daemon () =
  match Sys.getenv_opt "GAMEPILOT_DAEMON" with
  | Some path when path <> "" -> path
  | _ -> (
      let exe_dir = Filename.dirname Sys.executable_name in
      let candidates =
        [
          List.fold_left Filename.concat exe_dir [ "bin"; daemon_basename ];
          Filename.concat exe_dir daemon_basename;
        ]
      in
      match List.find_opt Sys.file_exists candidates with
      | Some found -> found
      | None -> "daemon/build/gamepilot_daemon")

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
