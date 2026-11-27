let ( let* ) = Result.bind
let max_log_lines = 120
let read_buf_size = 8192
let map_err code = Result.map_error (fun e -> (code, e))

type run_entry = {
  id : string;
  console : string;
  program : string;
  command : string;
  pid : int;
  fd : Unix.file_descr option;
  mutable status : string;
  mutable watch_url : string option;
  mutable logs : string list;
  mutable partial : string;
}

type t = {
  config_path : string;
  listen : string option;
  mutable next_id : int;
  mutable runs : run_entry list;
}

let create ~config_path ?listen () =
  { config_path; listen; next_id = 0; runs = [] }

let config_path st = st.config_path

let append_log entry line =
  (if entry.watch_url = None then
     match Ui_api.extract_watch_url line with
     | Some u -> entry.watch_url <- Some u
     | None -> ());
  let updated = entry.logs @ [ line ] in
  let extra = List.length updated - max_log_lines in
  entry.logs <-
    (if extra > 0 then List.filteri (fun i _ -> i >= extra) updated else updated)

let rec feed_lines entry = function
  | [] -> ()
  | [ last ] -> entry.partial <- last
  | line :: rest ->
      append_log entry line;
      feed_lines entry rest

let read_chunk entry fd =
  let buf = Bytes.create read_buf_size in
  let n = Unix.read fd buf 0 read_buf_size in
  if n > 0 then
    let chunk = entry.partial ^ Bytes.sub_string buf 0 n in
    feed_lines entry (String.split_on_char '\n' chunk)

let drain_fd entry fd =
  let r, _, _ = Unix.select [ fd ] [] [] 0.0 in
  if r <> [] then read_chunk entry fd

let finish_entry entry st =
  if entry.partial <> "" then (
    append_log entry entry.partial;
    entry.partial <- "");
  Option.iter Unix.close entry.fd;
  entry.status <-
    (match st with
    | Unix.WEXITED 0 -> "passed"
    | Unix.WSIGNALED _ -> "stopped"
    | _ -> "failed")

let poll_running entry =
  Option.iter (drain_fd entry) entry.fd;
  let pid, st = Unix.waitpid [ Unix.WNOHANG ] entry.pid in
  if pid <> 0 then finish_entry entry st

let reap_entry entry = if entry.status = "running" then poll_running entry
let reap_all st = List.iter reap_entry st.runs

let run_to_json r =
  `Assoc
    [
      ("id", `String r.id);
      ("console", `String r.console);
      ("program", `String r.program);
      ("command", `String r.command);
      ("status", `String r.status);
      ( "watch_url",
        Option.fold ~none:`Null ~some:(fun s -> `String s) r.watch_url );
      ("logs", `List (List.map (fun s -> `String s) r.logs));
    ]

let detect_external () =
  if Sys.win32 then []
  else
    let ic = Unix.open_process_in "ps -axo pid=,args=" in
    let lines = In_channel.input_lines ic in
    let _ = Unix.close_process_in ic in
    External_runs.parse_ps_lines lines
    |> List.map External_runs.enrich_watch_url

let hub_active st cid =
  List.find_opt (fun r -> r.console = cid && r.status = "running") st.runs
  |> Option.map run_to_json

let active_for_console st ext (c : Console_config.console) =
  match hub_active st c.id with
  | Some _ as r -> r
  | None ->
      External_runs.match_console ext c
      |> Option.map (External_runs.to_json ~console_id:c.id)

let external_entry_for st ext (c : Console_config.console) =
  if hub_active st c.id <> None then None
  else
    External_runs.match_console ext c
    |> Option.map (External_runs.to_json ~console_id:c.id)

let all_runs_json st =
  let ext = detect_external () in
  let ext_json =
    match Console_config.load ~path:st.config_path () with
    | Error _ -> []
    | Ok consoles -> List.filter_map (external_entry_for st ext) consoles
  in
  `Assoc [ ("runs", `List (List.map run_to_json st.runs @ ext_json)) ]

let launch_process st (req : Ui_api.launch_request) gp argv =
  let r_fd, w_fd = Unix.pipe () in
  Unix.set_close_on_exec r_fd;
  let devnull = Unix.openfile "/dev/null" [ Unix.O_RDONLY ] 0 in
  let pid = Unix.create_process gp (Array.of_list argv) devnull w_fd w_fd in
  Unix.close devnull;
  Unix.close w_fd;
  st.next_id <- st.next_id + 1;
  let entry =
    {
      id = Printf.sprintf "run-%d" st.next_id;
      console = req.console_id;
      program = req.program_id;
      command = String.concat " " argv;
      pid;
      fd = Some r_fd;
      status = "running";
      watch_url = None;
      logs = [];
      partial = "";
    }
  in
  st.runs <- entry :: st.runs;
  Ok (run_to_json entry)

let http_bad_request = 400
let http_not_found = 404
let http_conflict = 409
let http_server_error = 500

let check_external_free console =
  match External_runs.match_console (detect_external ()) console with
  | None -> Ok ()
  | Some ext ->
      let msg =
        Printf.sprintf "console %s is busy with external run %s (pid %d)"
          console.Console_config.id ext.program ext.pid
      in
      Error (http_conflict, msg)

let check_console_free st console =
  if hub_active st console.Console_config.id <> None then
    Error
      (http_conflict, "console " ^ console.id ^ " already has a running program")
  else check_external_free console

let spawn st (req : Ui_api.launch_request) =
  reap_all st;
  let* consoles =
    map_err http_server_error (Console_config.load ~path:st.config_path ())
  in
  let* console =
    Option.to_result
      ~none:(http_not_found, "unknown console " ^ req.console_id)
      (Console_config.find consoles req.console_id)
  in
  let* () = check_console_free st console in
  let gp = Sys.executable_name in
  let* argv =
    map_err http_bad_request
      (Ui_api.build_run_argv ~gamepilot:gp ?listen:st.listen ~console req)
  in
  launch_process st req gp argv

let kill_external_for console =
  let ext = detect_external () in
  Option.iter
    (fun (d : External_runs.t) -> Unix.kill d.pid Sys.sigterm)
    (External_runs.match_console ext console)

let stop_matching_daemon st console_id =
  match Console_config.load ~path:st.config_path () with
  | Error _ -> ()
  | Ok consoles ->
      Option.iter kill_external_for (Console_config.find consoles console_id)

let stop st id =
  reap_all st;
  match List.find_opt (fun r -> r.id = id) st.runs with
  | None -> Error (http_not_found, "unknown run " ^ id)
  | Some r ->
      if r.status = "running" then (
        Unix.kill r.pid Sys.sigterm;
        stop_matching_daemon st r.console;
        r.status <- "stopped");
      Ok (run_to_json r)
