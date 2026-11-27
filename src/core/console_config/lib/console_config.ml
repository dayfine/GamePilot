type backend =
  | Switch of { serial : string option; capture : string }
  | Mgba of { port : int }

type console = { id : string; name : string; backend : backend }
type t = console list

let ( let* ) = Result.bind
let default_mgba_port = 47810
let dir_perm = 0o755
let max_port = 65535

let default_path () =
  Filename.concat
    (Repo_io.Repo_files.data_dir "GAMEPILOT_CONFIG" "config")
    "consoles.json"

let is_id_char = function
  | 'a' .. 'z' | '0' .. '9' | '-' | '_' -> true
  | _ -> false

let valid_id s = s <> "" && String.for_all is_id_char s

let req_string ~where key fields =
  match List.assoc_opt key fields with
  | Some (`String s) when String.trim s <> "" -> Ok (String.trim s)
  | Some (`String _) -> Error (where ^ key ^ " is empty")
  | Some _ -> Error (where ^ key ^ " is not a string")
  | None -> Error (where ^ "missing " ^ key)

let opt_string ~where key fields =
  match List.assoc_opt key fields with
  | None | Some `Null -> Ok None
  | Some (`String s) when String.trim s = "" -> Ok None
  | Some (`String s) -> Ok (Some (String.trim s))
  | Some _ -> Error (where ^ key ^ " is not a string")

let opt_port ~where fields =
  match List.assoc_opt "mgba_port" fields with
  | None | Some `Null -> Ok default_mgba_port
  | Some (`Int p) when p > 0 && p <= max_port -> Ok p
  | Some (`Int p) ->
      Error (Printf.sprintf "%smgba_port is %d, not 1..%d" where p max_port)
  | Some _ -> Error (where ^ "mgba_port is not an integer")

let decode_backend ~where fields =
  let* kind = req_string ~where "backend" fields in
  match kind with
  | "switch" ->
      let* capture = req_string ~where "capture" fields in
      let* serial = opt_string ~where "serial" fields in
      Ok (Switch { serial; capture })
  | "mgba" ->
      let* port = opt_port ~where fields in
      Ok (Mgba { port })
  | other -> Error (where ^ "unknown backend " ^ other)

let decode_console_fields ~where fields =
  let* id = req_string ~where "id" fields in
  let* () =
    if valid_id id then Ok ()
    else
      Error (where ^ "id " ^ id ^ " must use lowercase letters, digits, - or _")
  in
  let* name = req_string ~where "name" fields in
  let* backend = decode_backend ~where fields in
  Ok { id; name; backend }

let decode_console i = function
  | `Assoc fields ->
      decode_console_fields ~where:(Printf.sprintf "consoles[%d]: " i) fields
  | _ -> Error (Printf.sprintf "consoles[%d]: expected a JSON object" i)

let decode_list items =
  let step (i, acc) item =
    let* c = decode_console i item in
    if List.exists (fun x -> x.id = c.id) acc then
      Error ("duplicate console id: " ^ c.id)
    else Ok (i + 1, c :: acc)
  in
  let* _, rev =
    List.fold_left
      (fun acc item -> Result.bind acc (fun s -> step s item))
      (Ok (0, []))
      items
  in
  Ok (List.rev rev)

let of_json = function
  | `Assoc fields -> (
      match List.assoc_opt "consoles" fields with
      | Some (`List items) -> decode_list items
      | Some _ -> Error "consoles must be a JSON list"
      | None -> Error "missing consoles field")
  | _ -> Error "consoles.json: expected a JSON object"

let encode_console c =
  let base = [ ("id", `String c.id); ("name", `String c.name) ] in
  let extra =
    match c.backend with
    | Switch { serial; capture } ->
        let s =
          match serial with Some v -> [ ("serial", `String v) ] | None -> []
        in
        [ ("backend", `String "switch"); ("capture", `String capture) ] @ s
    | Mgba { port } -> [ ("backend", `String "mgba"); ("mgba_port", `Int port) ]
  in
  `Assoc (base @ extra)

let to_json consoles =
  `Assoc [ ("consoles", `List (List.map encode_console consoles)) ]

let load ?path () =
  let path = Option.value path ~default:(default_path ()) in
  if not (Sys.file_exists path) then Ok []
  else
    let* json = Repo_io.Json_file.read path in
    of_json json

let rec ensure_dir dir =
  if dir <> "" && dir <> "." && dir <> "/" && not (Sys.file_exists dir) then (
    let parent = Filename.dirname dir in
    if parent <> dir then ensure_dir parent;
    Sys.mkdir dir dir_perm)

let save ?path consoles =
  let path = Option.value path ~default:(default_path ()) in
  ensure_dir (Filename.dirname path);
  Repo_io.Json_file.write path (to_json consoles)

let find consoles id = List.find_opt (fun c -> c.id = id) consoles

let upsert consoles c =
  if List.exists (fun x -> x.id = c.id) consoles then
    List.map (fun x -> if x.id = c.id then c else x) consoles
  else consoles @ [ c ]

let remove consoles id =
  let kept = List.filter (fun x -> x.id <> id) consoles in
  (kept, List.length kept <> List.length consoles)

let to_run_args c =
  match c.backend with
  | Switch { serial; capture } ->
      let s = match serial with Some v -> [ "--serial"; v ] | None -> [] in
      [ "--backend"; "switch"; "--capture"; capture ] @ s
  | Mgba { port } -> [ "--backend"; "mgba"; "--mgba-port"; string_of_int port ]

let extract_console_flag args =
  let rec loop found acc = function
    | [] -> Ok (found, List.rev acc)
    | [ "--console" ] -> Error "--console needs a console id"
    | "--console" :: id :: rest -> (
        match found with
        | Some _ -> Error "--console given twice"
        | None -> loop (Some id) acc rest)
    | a :: rest -> loop found (a :: acc) rest
  in
  loop None [] args

let unknown_console consoles id =
  match consoles with
  | [] ->
      Printf.sprintf
        "unknown console %S (none configured; run: gamepilot setup)" id
  | _ ->
      let names = String.concat ", " (List.map (fun c -> c.id) consoles) in
      Printf.sprintf "unknown console %S (configured: %s)" id names

let expand_console_flag ?path args =
  let* chosen, rest = extract_console_flag args in
  match chosen with
  | None -> Ok rest
  | Some id -> (
      let* consoles = load ?path () in
      match find consoles id with
      | Some c -> Ok (to_run_args c @ rest)
      | None -> Error (unknown_console consoles id))

let describe c =
  match c.backend with
  | Switch { serial = Some s; capture } ->
      Printf.sprintf "%s (%s): switch, serial=%s, capture=%s" c.id c.name s
        capture
  | Switch { serial = None; capture } ->
      Printf.sprintf "%s (%s): switch, capture=%s (no serial)" c.id c.name
        capture
  | Mgba { port } -> Printf.sprintf "%s (%s): mgba, port=%d" c.id c.name port

module Device_discovery = Device_discovery
