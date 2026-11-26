include Descriptor

let games = [ Plza_programs.game; Frlg_programs.game ]
let with_home (g : game) = Option.map (fun h -> (g, h)) g.switch_home

let home_ids () =
  String.concat ", "
    (List.map
       (fun ((g : game), _) -> g.game_id)
       (List.filter_map with_home games))

let by_id id =
  match List.find_opt (fun g -> g.game_id = id) games with
  | None ->
      Error ("no game " ^ id ^ "; games with Switch HOME data: " ^ home_ids ())
  | Some g ->
      Option.to_result
        ~none:(id ^ " has no Switch HOME data; games with it: " ^ home_ids ())
        (with_home g)

let only_one () =
  match List.filter_map with_home games with
  | [ one ] -> Ok one
  | _ ->
      Error ("set GAMEPILOT_LAB_GAME to the lab console's game: " ^ home_ids ())

let lab_game = function Some id -> by_id id | None -> only_one ()

let lab_game_of_env () =
  lab_game
    (match Sys.getenv_opt "GAMEPILOT_LAB_GAME" with
    | Some "" | None -> None
    | id -> id)

let all = Frlg_programs.all @ Plza_programs.all

let short_id p =
  let prefix = p.game.game_id ^ "." in
  let n = String.length prefix in
  if String.starts_with ~prefix p.id then
    String.sub p.id n (String.length p.id - n)
  else p.id

let find id =
  match List.find_opt (fun p -> p.id = id) all with
  | Some p -> Some p
  | None -> (
      match List.filter (fun p -> short_id p = id) all with
      | [ p ] -> Some p
      | _ -> None)

let segments path =
  String.split_on_char '/' path |> List.filter (fun s -> s <> "" && s <> ".")

let rec ends_with ~suffix list =
  list = suffix
  || match list with [] -> false | _ :: rest -> ends_with ~suffix rest

let of_plan_dir dir =
  let dir = segments dir in
  List.find_opt
    (fun p ->
      match p.checkpoints with
      | Some c -> ends_with ~suffix:(segments c) dir
      | None -> false)
    all

let locate = Repo_io.Repo_files.locate

let of_checkpoint id =
  let has_plan p =
    match Option.bind p.checkpoints locate with
    | Some dir -> Sys.file_exists (Filename.concat dir (id ^ ".plan.json"))
    | None -> false
  in
  List.find_opt has_plan all

let backend_name = function Mgba -> "mgba" | Switch -> "switch"
let viewport_name = function Nso_gba -> "nso-gba" | Native -> "native"

let viewport_mismatch p given =
  Printf.sprintf
    "--viewport %s: %s's game picture is %s (program_registry); drop \
     --viewport, or fix the program's descriptor"
    given p.id (viewport_name p.viewport)

let check_viewport program given =
  match (program, given) with
  | None, given -> Ok given
  | Some p, None -> Ok (Some (viewport_name p.viewport))
  | Some p, Some v when v = viewport_name p.viewport -> Ok (Some v)
  | Some p, Some v -> Error (viewport_mismatch p v)

let check_options program given =
  let decls = Option.fold ~none:[] ~some:(fun p -> p.options) program in
  Run_options.check decls given

let run_fields p =
  [
    ("game", p.game.game_id);
    ("game_name", p.game.game_name);
    ("program", p.id);
    ("program_name", p.name);
    ("group", String.concat " / " p.group);
  ]
