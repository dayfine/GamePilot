let ( let* ) = Result.bind
let http_ok = 200
let http_created = 201
let http_bad_request = 400
let http_not_found = 404
let http_server_error = 500

let json_resp code json =
  (code, "application/json; charset=utf-8", Yojson.Safe.to_string json)

let err_resp code msg = json_resp code (`Assoc [ ("error", `String msg) ])
let map_err code = Result.map_error (fun e -> (code, e))

let upsert_console st body =
  let path = Run_manager.config_path st in
  let* json = map_err http_bad_request (Repo_io.Json_file.of_string body) in
  let* c = map_err http_bad_request (Ui_api.decode_console_upsert json) in
  let* existing = map_err http_server_error (Console_config.load ~path ()) in
  let updated = Console_config.upsert existing c in
  map_err http_server_error (Console_config.save ~path updated)

let handle_post_console st body =
  match upsert_console st body with
  | Ok () -> json_resp http_ok (`Assoc [ ("ok", `Bool true) ])
  | Error (code, msg) -> err_resp code msg

let handle_post_run st body =
  let run =
    let* json = map_err http_bad_request (Repo_io.Json_file.of_string body) in
    let* req = map_err http_bad_request (Ui_api.decode_launch json) in
    Run_manager.spawn st req
  in
  match run with
  | Ok j -> json_resp http_created j
  | Error (code, msg) -> err_resp code msg

let handle_get_consoles st =
  let ext = Run_manager.detect_external () in
  let path = Run_manager.config_path st in
  match
    Ui_api.consoles_json ~path
      ~active_run:(Run_manager.active_for_console st ext)
      ()
  with
  | Ok j -> json_resp http_ok j
  | Error e -> err_resp http_server_error e

let handle_stop st path =
  match Ui_api.stop_id_of_path path with
  | None -> err_resp http_not_found ("not found: POST " ^ path)
  | Some id -> (
      match Run_manager.stop st id with
      | Ok j -> json_resp http_ok j
      | Error (code, msg) -> err_resp code msg)

let handle_get_history st =
  let runs_dir = Run_manager.runs_dir st in
  let entries = Run_history.load ~runs_dir () in
  json_resp http_ok (Run_history.to_json ~runs_dir entries)

let route st meth path body =
  Run_manager.reap_all st;
  match (meth, path) with
  | "GET", ("/" | "/index.html") ->
      (http_ok, "text/html; charset=utf-8", Ui_page.html)
  | "GET", "/api/programs" -> json_resp http_ok (Ui_api.programs_json ())
  | "GET", "/api/devices" -> json_resp http_ok (Ui_api.devices_json ())
  | "GET", "/api/consoles" -> handle_get_consoles st
  | "POST", "/api/consoles" -> handle_post_console st body
  | "GET", "/api/runs" -> json_resp http_ok (Run_manager.all_runs_json st)
  | "GET", "/api/history" -> handle_get_history st
  | "POST", "/api/runs" -> handle_post_run st body
  | "POST", p -> handle_stop st p
  | _ -> err_resp http_not_found ("not found: " ^ meth ^ " " ^ path)
