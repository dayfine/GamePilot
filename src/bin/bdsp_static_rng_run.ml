(* Loads the BDSP static RNG player eye-blink PNG template from an environment
   variable or committed repo asset before starting the live effect session. *)

let ( let* ) = Result.bind

let read_file path =
  if not (Sys.file_exists path) then
    Error (Printf.sprintf "template file not found: %s" path)
  else
    let ic = open_in_bin path in
    let n = in_channel_length ic in
    let bytes = really_input_string ic n in
    close_in ic;
    Ok bytes

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

let load_templates () =
  let* player_eye_png =
    resolve_template ~env_var:"GAMEPILOT_BDSP_PLAYER_EYE_PNG"
      ~repo_path:"src/games/pokemon/bdsp/assets/player_eye.png"
  in
  Ok
    {
      Bdsp_static_rng.Static_rng.player_eye_png;
      player_eye_box = Bdsp_static_rng.Static_rng.default_player_eye_box;
    }
