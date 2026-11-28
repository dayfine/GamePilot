type launch_request = {
  console_id : string;
  program_id : string;
  from_id : string option;
  to_id : string option;
  mode : string option;
  preflight : bool;
  options : (string * string) list;
}

let ( let* ) = Result.bind
let plan_suffix = ".plan.json"

let checkpoint_id_of_file name =
  let n = String.length name and s = String.length plan_suffix in
  if n > s && String.sub name (n - s) s = plan_suffix then
    Some (String.sub name 0 (n - s))
  else None

let checkpoints_of (p : Program_registry.t) =
  match Option.bind p.checkpoints Program_registry.locate with
  | None -> []
  | Some dir when not (Sys.file_exists dir && Sys.is_directory dir) -> []
  | Some dir ->
      Sys.readdir dir |> Array.to_list
      |> List.filter_map checkpoint_id_of_file
      |> List.sort String.compare

let option_json (d : Run_options.declared) =
  let value_fields =
    match d.value with
    | One_of vs ->
        [
          ("kind", `String "one_of");
          ("values", `List (List.map (fun s -> `String s) vs));
        ]
    | Int_range (lo, hi) ->
        [ ("kind", `String "int_range"); ("min", `Int lo); ("max", `Int hi) ]
    | Text -> [ ("kind", `String "text") ]
  in
  let presence_fields =
    match d.presence with
    | Required -> [ ("presence", `String "required"); ("default", `Null) ]
    | Optional -> [ ("presence", `String "optional"); ("default", `Null) ]
    | Default v -> [ ("presence", `String "default"); ("default", `String v) ]
  in
  `Assoc
    ([ ("key", `String d.key); ("doc", `String d.doc) ]
    @ value_fields @ presence_fields)

let program_json (p : Program_registry.t) =
  let strs xs = `List (List.map (fun s -> `String s) xs) in
  let backends = List.map Program_registry.backend_name p.backends in
  `Assoc
    [
      ("id", `String p.id);
      ("name", `String p.name);
      ("game_id", `String p.game.game_id);
      ("game_name", `String p.game.game_name);
      ("category", `String (Program_registry.category_name p.category));
      ("description", `String p.description);
      ("backends", strs backends);
      ("checkpoints", strs (checkpoints_of p));
      ("options", `List (List.map option_json p.options));
    ]

let programs_json () =
  `Assoc [ ("programs", `List (List.map program_json Program_registry.all)) ]

let capture_json (c : Console_config.Device_discovery.capture_device) =
  `Assoc
    [
      ("index", `String c.index);
      ("device_id", `String c.device_id);
      ("name", `String c.name);
    ]

let devices_json () =
  let serials = Console_config.Device_discovery.discover_serial_ports ()
  and captures = Console_config.Device_discovery.discover_capture_devices () in
  `Assoc
    [
      ("serial_ports", `List (List.map (fun s -> `String s) serials));
      ("capture_devices", `List (List.map capture_json captures));
    ]

let console_health (c : Console_config.console) =
  match c.backend with
  | Switch { serial = Some port; capture } ->
      let ok = Sys.win32 || Sys.file_exists port in
      let msg =
        if ok then Printf.sprintf "serial %s, capture %s" port capture
        else Printf.sprintf "serial port %s not connected" port
      in
      (ok, msg)
  | Switch { serial = None; capture } ->
      (true, Printf.sprintf "capture %s (no serial)" capture)
  | Mgba { port } -> (true, Printf.sprintf "mGBA bridge port %d" port)

let opt_json f = Option.fold ~none:`Null ~some:f

let console_status_json ~active_run (c : Console_config.console) =
  let ready, detail = console_health c and active = active_run c in
  let status =
    match active with
    | Some _ -> "running"
    | None -> if ready then "ready" else "offline"
  in
  let backend_fields =
    match c.backend with
    | Switch { serial; capture } ->
        [
          ("backend", `String "switch");
          ("capture", `String capture);
          ("serial", opt_json (fun s -> `String s) serial);
        ]
    | Mgba { port } -> [ ("backend", `String "mgba"); ("mgba_port", `Int port) ]
  in
  `Assoc
    ([
       ("id", `String c.id);
       ("name", `String c.name);
       ("ready", `Bool ready);
       ("status", `String status);
       ("detail", `String detail);
       ("watch_port", opt_json (fun p -> `Int p) c.watch_port);
       ("active_run", Option.value active ~default:`Null);
     ]
    @ backend_fields)

let consoles_json ?path ~active_run () =
  let resolved = Option.value path ~default:(Console_config.default_path ()) in
  let* consoles = Console_config.load ~path:resolved () in
  Ok
    (`Assoc
       [
         ("config_path", `String resolved);
         ( "consoles",
           `List (List.map (console_status_json ~active_run) consoles) );
       ])

let decode_console_upsert json =
  match Console_config.of_json (`Assoc [ ("consoles", `List [ json ]) ]) with
  | Ok [ c ] -> Ok c
  | Ok _ -> Error "expected one console object"
  | Error e -> Error e

let string_field key fields =
  match List.assoc_opt key fields with
  | Some (`String s) when String.trim s <> "" -> Ok (String.trim s)
  | Some (`String _) -> Error (key ^ " is empty")
  | Some _ -> Error (key ^ " must be a string")
  | None -> Error ("missing " ^ key)

let opt_string_field key fields =
  match List.assoc_opt key fields with
  | None | Some `Null -> Ok None
  | Some (`String s) when String.trim s = "" -> Ok None
  | Some (`String s) -> Ok (Some (String.trim s))
  | Some _ -> Error (key ^ " must be a string")

let opt_bool_field key ~default fields =
  match List.assoc_opt key fields with
  | None | Some `Null -> Ok default
  | Some (`Bool b) -> Ok b
  | Some _ -> Error (key ^ " must be a boolean")

let decode_option_entry acc (k, v) =
  let* pairs = acc in
  match v with
  | `String s when String.trim s = "" -> Ok pairs
  | `String s -> Ok ((k, String.trim s) :: pairs)
  | `Int n -> Ok ((k, string_of_int n) :: pairs)
  | `Null -> Ok pairs
  | _ -> Error ("option " ^ k ^ " must be a string or integer")

let decode_options fields =
  match List.assoc_opt "options" fields with
  | None | Some `Null -> Ok []
  | Some (`Assoc kvs) ->
      let* rev = List.fold_left decode_option_entry (Ok []) kvs in
      Ok (List.rev rev)
  | Some _ -> Error "options must be a JSON object"

let decode_launch = function
  | `Assoc fields ->
      let* console_id = string_field "console" fields in
      let* program_id = string_field "program" fields in
      let* from_id = opt_string_field "from" fields in
      let* to_id = opt_string_field "to" fields in
      let* mode_opt = opt_string_field "mode" fields in
      let mode =
        match mode_opt with Some "default" -> None | other -> other
      in
      let* preflight = opt_bool_field "preflight" ~default:false fields in
      let* options = decode_options fields in
      Ok { console_id; program_id; from_id; to_id; mode; preflight; options }
  | _ -> Error "expected a JSON object"

let mode_args = function None -> [] | Some m -> [ "--mode"; m ]

let range_args (p : Program_registry.t) (req : launch_request) =
  let cps = checkpoints_of p in
  let first = match cps with x :: _ -> Some x | [] -> None in
  let last = match List.rev cps with x :: _ -> Some x | [] -> None in
  let from_id = match req.from_id with Some _ as f -> f | None -> first in
  let to_id = match req.to_id with Some _ as t -> t | None -> last in
  match (from_id, to_id) with
  | Some f, _ when req.preflight -> Ok [ "--preflight"; "--from"; f ]
  | Some f, Some t ->
      let mode = Option.value req.mode ~default:"testing" in
      Ok [ "--from"; f; "--to"; t; "--mode"; mode ]
  | None, None -> Ok (mode_args req.mode)
  | _ -> Error (p.id ^ " has incomplete checkpoint range")

let opt_flag flag = function Some v when v <> "" -> [ flag; v ] | _ -> []

let watch_args ~preflight ?listen ?watch_port () =
  if preflight then []
  else
    let listen_v =
      Option.bind listen (fun a -> if a <> "127.0.0.1" then Some a else None)
    in
    let port_v = Option.map string_of_int watch_port in
    ("--watch" :: opt_flag "--listen" listen_v) @ opt_flag "--watch-port" port_v

let build_run_argv ~gamepilot ?listen ?runs_dir
    ~(console : Console_config.console) req =
  let* prog =
    Option.to_result
      ~none:("unknown program " ^ req.program_id)
      (Program_registry.find req.program_id)
  in
  let* checked = Program_registry.check_options (Some prog) req.options in
  let* range = range_args prog req in
  let opt_args =
    List.concat_map
      (fun (k, v) -> [ "--options"; k ^ "=" ^ v ])
      (Run_options.pairs checked)
  and watch =
    watch_args ~preflight:req.preflight ?listen ?watch_port:console.watch_port
      ()
  in
  Ok
    ([ gamepilot; "run"; prog.id ]
    @ Console_config.to_run_args console
    @ range @ watch
    @ opt_flag "--runs-dir" runs_dir
    @ opt_args)

let extract_watch_url line =
  let prefix = "http://" in
  let n = String.length line and p = String.length prefix in
  let rec end_ j =
    if j >= n || line.[j] = ' ' || line.[j] = '\t' || line.[j] = '\r' then j
    else end_ (j + 1)
  in
  let rec find i =
    if i + p > n then None
    else if String.sub line i p = prefix then
      Some (String.sub line i (end_ i - i))
    else find (i + 1)
  in
  find 0

let split_http raw =
  let n = String.length raw in
  let rec find i =
    if i + 4 > n then (raw, "")
    else if String.sub raw i 4 = "\r\n\r\n" then
      (String.sub raw 0 i, String.sub raw (i + 4) (n - i - 4))
    else find (i + 1)
  in
  let head, body = find 0 in
  match String.split_on_char '\n' head with
  | line :: _ -> (
      match String.split_on_char ' ' (String.trim line) with
      | meth :: path :: _ -> Some (meth, path, body)
      | _ -> None)
  | [] -> None

let status_text = function
  | 200 -> "OK"
  | 201 -> "Created"
  | 400 -> "Bad Request"
  | 404 -> "Not Found"
  | 409 -> "Conflict"
  | _ -> "Internal Server Error"

let stop_id_of_path path =
  let p = "/api/runs/" and s = "/stop" in
  let n = String.length path
  and pl = String.length p
  and sl = String.length s in
  if
    n > pl + sl
    && String.starts_with ~prefix:p path
    && String.ends_with ~suffix:s path
  then Some (String.sub path pl (n - pl - sl))
  else None
