module J = Json_field

type mode =
  | Everything
  | Missing_on_dex
  | Version_exclusive
  | Version_exclusive_uncaught
  | Specific_list of string list

let ( let* ) = Result.bind
let config_env = "GAMEPILOT_FRLG_CONFIG"
let progress_file = "dex_progress.json"
let dir_perm = 0o755

(* FireRed and LeafGreen Kanto / Sevii version-exclusive species slugs. *)
let version_exclusives =
  [
    (* FireRed *)
    "ekans";
    "arbok";
    "oddish";
    "gloom";
    "vileplume";
    "psyduck";
    "golduck";
    "growlithe";
    "arcanine";
    "shellder";
    "cloyster";
    "electabuzz";
    "scyther";
    "qwilfish";
    "delibird";
    "skarmory";
    "wooper";
    "quagsire";
    "murkrow";
    (* LeafGreen *)
    "sandshrew";
    "sandslash";
    "vulpix";
    "ninetales";
    "bellsprout";
    "weepinbell";
    "victreebel";
    "slowpoke";
    "slowbro";
    "staryu";
    "starmie";
    "magmar";
    "pinsir";
    "magby";
    "marill";
    "azumarill";
    "misdreavus";
    "sneasel";
    "remoraid";
    "octillery";
    "mantine";
  ]

let normalize slug = String.lowercase_ascii (String.trim slug)
let is_version_exclusive slug = List.mem (normalize slug) version_exclusives

let parse_species raw =
  String.split_on_char ',' raw
  |> List.map normalize
  |> List.filter (fun s -> s <> "")

let parse_specific = function
  | None ->
      Error "--options target=specific-list requires --options species=SLUG,..."
  | Some raw -> (
      match parse_species raw with
      | [] -> Error "--options species=... must name at least one species"
      | list -> Ok (Some (Specific_list list)))

let reject_species mode = function
  | None -> Ok (Some mode)
  | Some _ ->
      Error
        "--options species=... is only used with --options target=specific-list"

let of_options options =
  let species = Run_options.find options "species" in
  match Run_options.find options "target" with
  | None -> Ok None
  | Some "everything" -> reject_species Everything species
  | Some "missing-on-dex" -> reject_species Missing_on_dex species
  | Some "version-exclusive" -> reject_species Version_exclusive species
  | Some "version-exclusive-uncaught" ->
      reject_species Version_exclusive_uncaught species
  | Some "specific-list" -> parse_specific species
  | Some other -> Error ("unknown target mode: " ^ other)

let should_run ~mode ~caught = function
  | None -> true
  | Some slug -> (
      let s = normalize slug in
      match mode with
      | Everything | Missing_on_dex -> not (List.mem s caught)
      | Version_exclusive -> is_version_exclusive s
      | Version_exclusive_uncaught ->
          is_version_exclusive s && not (List.mem s caught)
      | Specific_list want -> List.mem s want)

let event_species (e : Pokemon_engine.Plan.event) =
  match (e.kind, e.way) with
  | Named_action args, Some ("wild_rng" | "capture") -> (
      match J.find "species" args with
      | Some (`String s) when String.trim s <> "" -> Some (normalize s)
      | _ -> None)
  | _ -> None

let plan_species (plan : Pokemon_engine.Plan.t) =
  List.find_map event_species plan.checkpoint.events

let default_path () =
  Filename.concat (Repo_io.Repo_files.data_dir config_env "frlg") progress_file

let parse_caught_entry ~path acc = function
  | `String s -> Result.map (fun a -> normalize s :: a) acc
  | _ -> Error (path ^ ": caught entry is not a string")

let parse_caught_list ~path = function
  | `List items ->
      let* rev = List.fold_left (parse_caught_entry ~path) (Ok []) items in
      Ok (List.sort_uniq String.compare rev)
  | _ -> Error (path ^ ": caught must be a JSON list of strings")

let load_caught ?path () =
  let path = Option.value path ~default:(default_path ()) in
  if not (Sys.file_exists path) then Ok []
  else
    let* json = Repo_io.Json_file.read path in
    match json with
    | `Assoc fields -> (
        match List.assoc_opt "caught" fields with
        | None -> Ok []
        | Some v -> parse_caught_list ~path v)
    | _ -> Error (path ^ ": expected a JSON object")

let rec ensure_dir dir =
  if dir <> "" && dir <> "." && dir <> "/" && not (Sys.file_exists dir) then (
    let parent = Filename.dirname dir in
    if parent <> dir then ensure_dir parent;
    Unix.mkdir dir dir_perm)

let record_caught ?path species =
  let path = Option.value path ~default:(default_path ()) in
  let* existing = load_caught ~path () in
  let updated = List.sort_uniq String.compare (normalize species :: existing) in
  ensure_dir (Filename.dirname path);
  let json =
    `Assoc [ ("caught", `List (List.map (fun s -> `String s) updated)) ]
  in
  Repo_io.Json_file.write path json

let skip_reason ~mode species =
  match mode with
  | Everything | Missing_on_dex ->
      species ^ " already recorded in dex_progress.json"
  | Version_exclusive -> species ^ " is not a version exclusive"
  | Version_exclusive_uncaught ->
      if is_version_exclusive species then
        species ^ " already recorded in dex_progress.json"
      else species ^ " is not a version exclusive"
  | Specific_list _ -> species ^ " not in --options species list"

let filter_one ~plan_dir ~mode ~caught (kept, skipped) id =
  let* plan = Plan_dir.load_plan ~plan_dir id in
  let species = plan_species plan in
  if should_run ~mode ~caught species then Ok (id :: kept, skipped)
  else
    let name = Option.value species ~default:id in
    Ok (kept, (id, skip_reason ~mode name) :: skipped)

let filter_checkpoints ~plan_dir ~mode ~caught ids =
  let* kept, skipped =
    List.fold_left
      (fun acc id ->
        Result.bind acc (fun pair -> filter_one ~plan_dir ~mode ~caught pair id))
      (Ok ([], []))
      ids
  in
  Ok (List.rev kept, List.rev skipped)
