type t = {
  pid : int;
  program : string;
  serial : string option;
  mgba_port : int option;
  registry : string option;
  watch_url : string option;
  run_folder : string option;
  command : string;
}

let split_words s =
  String.split_on_char ' ' s |> List.filter (fun w -> w <> "" && w <> "\t")

let rec flag_value key = function
  | [] | [ _ ] -> None
  | a :: (b :: _ as tail) -> if a = key then Some b else flag_value key tail

let has_flag key words = List.exists (fun w -> w = key) words

let is_daemon_bin word =
  Filename.basename word = "gamepilot_daemon"
  || Filename.basename word = "gamepilot_daemon.exe"

let is_gamepilot_bin word =
  let base = Filename.basename word in
  base = "gamepilot" || base = "gamepilot.exe"

let daemon_mgba_port words =
  if flag_value "--backend" words = Some "mgba" then
    Option.bind (flag_value "--port" words) int_of_string_opt
  else None

let make_daemon_run pid command words serial mgba_port =
  let program =
    Option.value (flag_value "--checkpoint" words) ~default:"daemon"
  in
  {
    pid;
    program;
    serial;
    mgba_port;
    registry = flag_value "--registry" words;
    watch_url = None;
    run_folder = flag_value "--run-folder" words;
    command;
  }

let parse_daemon_fields pid command words =
  let serial = flag_value "--serial" words in
  let mgba_port = daemon_mgba_port words in
  if serial = None && mgba_port = None then None
  else Some (make_daemon_run pid command words serial mgba_port)

let parse_daemon pid command words =
  if has_flag "--hub" words then None else parse_daemon_fields pid command words

let make_cli_run pid command program serial mgba_port =
  {
    pid;
    program;
    serial;
    mgba_port;
    registry = None;
    watch_url = None;
    run_folder = None;
    command;
  }

let parse_cli_run pid command = function
  | _ :: "run" :: program :: rest ->
      let serial = flag_value "--serial" rest in
      let mgba_port =
        Option.bind (flag_value "--mgba-port" rest) int_of_string_opt
      in
      if serial = None && mgba_port = None then None
      else Some (make_cli_run pid command program serial mgba_port)
  | _ -> None

let parse_words pid words =
  let cmd = String.concat " " words in
  match words with
  | bin :: _ when is_daemon_bin bin -> parse_daemon pid cmd words
  | bin :: _ when is_gamepilot_bin bin -> parse_cli_run pid cmd words
  | _ -> None

let parse_line line =
  match split_words (String.trim line) with
  | pid_s :: words ->
      Option.bind (int_of_string_opt pid_s) (fun pid -> parse_words pid words)
  | [] -> None

let parse_ps_lines lines = List.filter_map parse_line lines

let watch_url_from_registry dir pid =
  let path = Filename.concat dir (Printf.sprintf "%d.json" pid) in
  match Repo_io.Json_file.read path with
  | Ok (`Assoc fields) -> (
      match List.assoc_opt "port" fields with
      | Some (`Int port) when port > 0 ->
          Some (Printf.sprintf "http://127.0.0.1:%d/" port)
      | _ -> None)
  | _ -> None

let enrich_watch_url r =
  match (r.watch_url, r.registry) with
  | Some _, _ | None, None -> r
  | None, Some dir -> { r with watch_url = watch_url_from_registry dir r.pid }

let matches_console (c : Console_config.console) r =
  match c.backend with
  | Switch { serial = Some s; _ } -> r.serial = Some s
  | Switch { serial = None; _ } -> false
  | Mgba { port } -> r.mgba_port = Some port

let match_console runs console =
  let hits = List.filter (matches_console console) runs in
  match List.find_opt (fun r -> r.registry <> None) hits with
  | Some r -> Some r
  | None -> ( match hits with r :: _ -> Some r | [] -> None)

let opt_str = Option.fold ~none:`Null ~some:(fun s -> `String s)

let to_json ~console_id r =
  `Assoc
    [
      ("id", `String (Printf.sprintf "ext-%d" r.pid));
      ("console", `String console_id);
      ("program", `String r.program);
      ("command", `String r.command);
      ("status", `String "running");
      ("external", `Bool true);
      ("pid", `Int r.pid);
      ("watch_url", opt_str r.watch_url);
      ("run_folder", opt_str r.run_folder);
      ("logs", `List []);
    ]
