type entry = {
  boot_offset_ms : int;
  seed_shift : int;
  ingame_offset : int;
  updated_at : string;
}

type store = (string * entry) list

type miss_observation = {
  target_seed : int;
  observed_seed : int;
  target_advance : int;
  observed_advance : int;
}

let ( let* ) = Result.bind
let format_version = 1
let default_console_id = "default"
let console_id_env = "GAMEPILOT_CONSOLE_ID"
let config_env = "GAMEPILOT_FRLG_CONFIG"
let calibration_file = "switch_rng_calibration.json"
let seed_mask = 0xffff
let dir_perm = 0o755

let empty_entry =
  { boot_offset_ms = 0; seed_shift = 0; ingame_offset = 0; updated_at = "" }

let normalize_id id =
  let trimmed = String.trim id in
  if trimmed = "" then default_console_id else trimmed

let current_console_id () =
  match Sys.getenv_opt console_id_env with
  | None -> default_console_id
  | Some raw -> normalize_id raw

let default_path () =
  Filename.concat
    (Repo_io.Repo_files.data_dir config_env "frlg")
    calibration_file

let entry_to_json e =
  `Assoc
    [
      ("boot_offset_ms", `Int e.boot_offset_ms);
      ("seed_shift", `Int e.seed_shift);
      ("ingame_offset", `Int e.ingame_offset);
      ("updated_at", `String e.updated_at);
    ]

let to_json store =
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) store in
  `Assoc
    [
      ("version", `Int format_version);
      ( "consoles",
        `Assoc (List.map (fun (id, e) -> (id, entry_to_json e)) sorted) );
    ]

let int_field ~ctx fields name =
  match List.assoc_opt name fields with
  | Some (`Int n) -> Ok n
  | Some _ -> Error (Printf.sprintf "%s.%s must be an integer" ctx name)
  | None -> Error (Printf.sprintf "%s: missing %s" ctx name)

let string_field ~ctx fields name =
  match List.assoc_opt name fields with
  | Some (`String s) -> Ok s
  | Some _ -> Error (Printf.sprintf "%s.%s must be a string" ctx name)
  | None -> Error (Printf.sprintf "%s: missing %s" ctx name)

let check_seed_shift ~ctx n =
  if n < 0 || n > seed_mask then
    Error (Printf.sprintf "%s.seed_shift is %d, not 0..%d" ctx n seed_mask)
  else Ok n

let entry_of_json ~ctx = function
  | `Assoc fields ->
      let* boot_offset_ms = int_field ~ctx fields "boot_offset_ms" in
      let* raw_shift = int_field ~ctx fields "seed_shift" in
      let* seed_shift = check_seed_shift ~ctx raw_shift in
      let* ingame_offset = int_field ~ctx fields "ingame_offset" in
      let* updated_at = string_field ~ctx fields "updated_at" in
      Ok { boot_offset_ms; seed_shift; ingame_offset; updated_at }
  | _ -> Error (ctx ^ ": expected a JSON object")

let find store ~console_id = List.assoc_opt (normalize_id console_id) store

let upsert store ~console_id entry =
  let key = normalize_id console_id in
  let rest = List.filter (fun (k, _) -> k <> key) store in
  List.sort (fun (a, _) (b, _) -> String.compare a b) ((key, entry) :: rest)

let parse_console acc (raw_id, value) =
  let* store = acc in
  let id = String.trim raw_id in
  if id = "" then Error "consoles: console ID must not be empty"
  else
    let* entry = entry_of_json ~ctx:("consoles." ^ id) value in
    Ok (upsert store ~console_id:id entry)

let check_version fields =
  match List.assoc_opt "version" fields with
  | Some (`Int v) when v = format_version -> Ok ()
  | Some (`Int v) ->
      Error
        (Printf.sprintf "unsupported calibration version %d (expected %d)" v
           format_version)
  | Some _ -> Error "version must be an integer"
  | None -> Error "missing version"

let of_json = function
  | `Assoc fields -> (
      let* () = check_version fields in
      match List.assoc_opt "consoles" fields with
      | Some (`Assoc entries) -> List.fold_left parse_console (Ok []) entries
      | Some _ -> Error "consoles must be a JSON object"
      | None -> Error "missing consoles")
  | _ -> Error "expected a JSON object"

let refine_offset ?updated_at entry obs =
  let seed_delta = obs.observed_seed - obs.target_seed in
  let seed_shift = (entry.seed_shift + seed_delta) land seed_mask in
  let advance_delta = obs.target_advance - obs.observed_advance in
  let ingame_offset = entry.ingame_offset + advance_delta in
  let updated_at = Option.value updated_at ~default:entry.updated_at in
  { entry with seed_shift; ingame_offset; updated_at }

let to_calibrations entry =
  let seed_offset =
    if entry.boot_offset_ms = 0 then 0
    else
      int_of_float
        (Float.round
           (float_of_int entry.boot_offset_ms
           /. Rng_timings.switch.frame_duration_ms))
  in
  {
    Rng_timings.no_calibrations with
    seed_offset;
    ingame_offset = entry.ingame_offset;
  }

let load ?path () =
  let path = Option.value path ~default:(default_path ()) in
  if not (Sys.file_exists path) then Ok []
  else
    let* json = Repo_io.Json_file.read path in
    of_json json |> Result.map_error (fun e -> path ^ ": " ^ e)

let rec ensure_dir dir =
  if dir <> "" && dir <> "." && dir <> "/" && not (Sys.file_exists dir) then (
    let parent = Filename.dirname dir in
    if parent <> dir then ensure_dir parent;
    Sys.mkdir dir dir_perm)

let save ?path store =
  let path = Option.value path ~default:(default_path ()) in
  ensure_dir (Filename.dirname path);
  Repo_io.Json_file.write path (to_json store)

let load_console ?path ?console_id () =
  let id = Option.value console_id ~default:(current_console_id ()) in
  let* store = load ?path () in
  Ok (find store ~console_id:id)

let record_miss ?path ?console_id ?updated_at obs =
  let id = Option.value console_id ~default:(current_console_id ()) in
  let* store = load ?path () in
  let existing =
    Option.value (find store ~console_id:id) ~default:empty_entry
  in
  let updated = refine_offset ?updated_at existing obs in
  let* () = save ?path (upsert store ~console_id:id updated) in
  Ok updated
