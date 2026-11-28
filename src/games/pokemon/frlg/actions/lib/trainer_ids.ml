type t = { tid : int option; sid : int option }

let none = { tid = None; sid = None }
let max_id = 0xffff
let config_env = "GAMEPILOT_FRLG_CONFIG"
let config_file = "trainer_ids.json"
let ( let* ) = Result.bind
let env_var name = "GAMEPILOT_FRLG_" ^ String.uppercase_ascii name

let check_id ~label n =
  if n >= 0 && n <= max_id then Ok (Some n)
  else Error (Printf.sprintf "%s is %d, not 0..%d" label n max_id)

let env_id name =
  let var = env_var name in
  match Sys.getenv_opt var with
  | None | Some "" -> Ok None
  | Some raw -> (
      match int_of_string_opt (String.trim raw) with
      | None -> Error (Printf.sprintf "%s is %S, not 0..%d" var raw max_id)
      | Some n -> check_id ~label:var n)

let json_id ~path name fields =
  match List.assoc_opt name fields with
  | None | Some `Null -> Ok None
  | Some (`Int n) -> check_id ~label:(path ^ ": " ^ name) n
  | Some _ -> Error (Printf.sprintf "%s: %s is not an integer" path name)

let file_ids () =
  let path =
    Filename.concat (Repo_io.Repo_files.data_dir config_env "frlg") config_file
  in
  if not (Sys.file_exists path) then Ok none
  else
    let* json = Repo_io.Json_file.read path in
    match json with
    | `Assoc fields ->
        let* tid = json_id ~path "tid" fields in
        let* sid = json_id ~path "sid" fields in
        Ok { tid; sid }
    | _ -> Error (path ^ ": expected a JSON object")

let pick a b = if Option.is_some a then a else b

let load () =
  let* tid = env_id "tid" in
  let* sid = env_id "sid" in
  let* f =
    if Option.is_some tid && Option.is_some sid then Ok none else file_ids ()
  in
  Ok { tid = pick tid f.tid; sid = pick sid f.sid }
