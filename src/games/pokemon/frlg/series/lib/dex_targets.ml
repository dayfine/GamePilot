module J = Json_field

type mode =
  | Everything
  | Missing_on_dex
  | Version_exclusive
  | Version_exclusive_uncaught
  | Specific_list of string list

type counts = (string * int) list

let ( let* ) = Result.bind
let config_env = "GAMEPILOT_FRLG_CONFIG"
let progress_file = "dex_progress.json"
let progress_version = 2
let default_target_count = 1
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

(* FireRed Kanto exclusive evolution-line target counts (13 shinies total). *)
let line_two = 2
let line_three = 3

let target_counts =
  [
    ("ekans", line_two);
    ("growlithe", line_two);
    ("oddish", line_three);
    ("psyduck", line_two);
    ("shellder", line_two);
    ("electabuzz", default_target_count);
    ("scyther", default_target_count);
  ]

let normalize slug = String.lowercase_ascii (String.trim slug)
let is_version_exclusive slug = List.mem (normalize slug) version_exclusives

let count_of counts slug =
  Option.value ~default:0 (List.assoc_opt (normalize slug) counts)

let required_count slug =
  Option.value ~default:default_target_count
    (List.assoc_opt (normalize slug) target_counts)

let remaining ~counts ?target slug =
  let goal = Option.value target ~default:(required_count slug) in
  max 0 (goal - count_of counts slug)

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

let should_run ~mode ~counts = function
  | None -> true
  | Some slug -> (
      let s = normalize slug in
      match mode with
      | Everything | Missing_on_dex -> remaining ~counts s > 0
      | Version_exclusive -> is_version_exclusive s
      | Version_exclusive_uncaught ->
          is_version_exclusive s && remaining ~counts s > 0
      | Specific_list want -> List.mem s want)

let event_species (e : Pokemon_engine.Plan.event) =
  match (e.kind, e.way) with
  | Named_action args, Some ("wild_rng" | "capture" | "gift_rng") -> (
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

let parse_v1_caught ~path = function
  | `List items ->
      let* rev = List.fold_left (parse_caught_entry ~path) (Ok []) items in
      Ok
        (List.sort_uniq String.compare rev
        |> List.map (fun s -> (s, default_target_count)))
  | _ -> Error (path ^ ": caught must be a JSON list of strings")

let upsert_count counts slug n =
  let s = normalize slug in
  let rest = List.filter (fun (k, _) -> k <> s) counts in
  let merged = if n > 0 then (s, n) :: rest else rest in
  List.sort (fun (a, _) (b, _) -> String.compare a b) merged

let parse_count_entry ~path acc (slug, value) =
  let* counts = acc in
  match value with
  | `Int n when n >= 0 -> Ok (upsert_count counts slug n)
  | _ ->
      Error
        (Printf.sprintf "%s: counts.%s must be a non-negative integer" path slug)

let parse_v2_counts ~path = function
  | `Assoc entries -> List.fold_left (parse_count_entry ~path) (Ok []) entries
  | _ -> Error (path ^ ": counts must be a JSON object")

let check_version ~path fields =
  match List.assoc_opt "version" fields with
  | None -> Ok ()
  | Some (`Int v) when v = progress_version -> Ok ()
  | Some _ ->
      Error
        (Printf.sprintf "%s: unsupported dex_progress version (expected %d)"
           path progress_version)

let parse_progress_fields ~path fields =
  let* () = check_version ~path fields in
  match (List.assoc_opt "counts" fields, List.assoc_opt "caught" fields) with
  | Some v, _ -> parse_v2_counts ~path v
  | None, Some v -> parse_v1_caught ~path v
  | None, None -> Ok []

let load_counts ?path () =
  let path = Option.value path ~default:(default_path ()) in
  if not (Sys.file_exists path) then Ok []
  else
    let* json = Repo_io.Json_file.read path in
    match json with
    | `Assoc fields -> parse_progress_fields ~path fields
    | _ -> Error (path ^ ": expected a JSON object")

let load_caught ?path () = Result.map (List.map fst) (load_counts ?path ())

let rec ensure_dir dir =
  if dir <> "" && dir <> "." && dir <> "/" && not (Sys.file_exists dir) then (
    let parent = Filename.dirname dir in
    if parent <> dir then ensure_dir parent;
    Unix.mkdir dir dir_perm)

let record_caught ?path species =
  let path = Option.value path ~default:(default_path ()) in
  let* existing = load_counts ~path () in
  let s = normalize species in
  let updated = upsert_count existing s (count_of existing s + 1) in
  ensure_dir (Filename.dirname path);
  let json =
    `Assoc
      [
        ("version", `Int progress_version);
        ("counts", `Assoc (List.map (fun (k, n) -> (k, `Int n)) updated));
      ]
  in
  Repo_io.Json_file.write path json

let quota_met_reason ~counts species =
  Printf.sprintf "%s already met target (%d/%d) in dex_progress.json" species
    (count_of counts species) (required_count species)

let skip_reason ~mode ~counts species =
  match mode with
  | Everything | Missing_on_dex -> quota_met_reason ~counts species
  | Version_exclusive -> species ^ " is not a version exclusive"
  | Version_exclusive_uncaught ->
      if is_version_exclusive species then quota_met_reason ~counts species
      else species ^ " is not a version exclusive"
  | Specific_list _ -> species ^ " not in --options species list"

let filter_one ~plan_dir ~mode ~counts (kept, skipped) id =
  let* plan = Plan_dir.load_plan ~plan_dir id in
  let species = plan_species plan in
  if should_run ~mode ~counts species then Ok (id :: kept, skipped)
  else
    let name = Option.value species ~default:id in
    Ok (kept, (id, skip_reason ~mode ~counts name) :: skipped)

let filter_checkpoints ~plan_dir ~mode ~counts ids =
  let* kept, skipped =
    List.fold_left
      (fun acc id ->
        Result.bind acc (fun pair -> filter_one ~plan_dir ~mode ~counts pair id))
      (Ok ([], []))
      ids
  in
  Ok (List.rev kept, List.rev skipped)
