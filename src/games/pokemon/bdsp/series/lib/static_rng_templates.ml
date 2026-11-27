let ( let* ) = Result.bind

type loaded = {
  player_eye_png : string;
  chamber_eye_png : string;
  frame_dir : string option;
}

let read_file path =
  if not (Sys.file_exists path) then
    Error (Printf.sprintf "template file not found: %s" path)
  else Ok (In_channel.with_open_bin path In_channel.input_all)

let find_repo_template ~env_var ~repo_path =
  match Repo_io.Repo_files.locate repo_path with
  | Some p -> read_file p
  | None ->
      Error
        (Printf.sprintf "missing eye template: set %s or place %s in the repo"
           env_var repo_path)

let resolve_template ~env_var ~repo_path =
  match Sys.getenv_opt env_var with
  | Some p when p <> "" -> read_file p
  | _ -> find_repo_template ~env_var ~repo_path

let load () =
  let* player_eye_png =
    resolve_template ~env_var:"GAMEPILOT_BDSP_PLAYER_EYE_PNG"
      ~repo_path:"src/games/pokemon/bdsp/assets/player_eye.png"
  in
  let* chamber_eye_png =
    match Sys.getenv_opt "GAMEPILOT_BDSP_CHAMBER_EYE_PNG" with
    | Some p when p <> "" -> read_file p
    | _ -> Ok player_eye_png
  in
  let frame_dir =
    match Sys.getenv_opt "GAMEPILOT_BDSP_FRAME_DIR" with
    | Some "" | None -> None
    | Some dir -> Some dir
  in
  Ok { player_eye_png; chamber_eye_png; frame_dir }
