(* gamepilot ui [--port N] [--listen ADDR] [--config FILE]
   Local HTTP control hub (docs/design/Release-and-Onboarding.md): serves the
   console status and program launcher page, exposes /api/consoles,
   /api/devices, /api/programs, /api/runs, and dispatches `gamepilot run` child
   processes through Ui_hub.Run_manager. *)

let ( let* ) = Result.bind
let usage = "  gamepilot ui [--port N] [--listen ADDR] [--config FILE]\n"
let default_port = 47902
let default_listen = "127.0.0.1"
let read_buf_size = 8192
let poll_timeout_s = 0.25
let backlog = 16

type flags = { port : int; listen : string; config : string option }

let rec parse f = function
  | [] -> Ok f
  | "--port" :: p :: rest -> (
      match int_of_string_opt p with
      | Some n when n > 0 -> parse { f with port = n } rest
      | _ -> Error ("ui: bad --port " ^ p))
  | "--listen" :: addr :: rest -> parse { f with listen = addr } rest
  | "--config" :: p :: rest -> parse { f with config = Some p } rest
  | a :: _ -> Error ("ui: unknown argument " ^ a)

let json_resp code json =
  (code, "application/json; charset=utf-8", Yojson.Safe.to_string json)

let err_resp code msg = json_resp code (`Assoc [ ("error", `String msg) ])
let map_err code = Result.map_error (fun e -> (code, e))

let upsert_console st body =
  let path = Ui_hub.Run_manager.config_path st in
  let* json = map_err 400 (Repo_io.Json_file.of_string body) in
  let* c = map_err 400 (Ui_hub.Ui_api.decode_console_upsert json) in
  let* existing = map_err 500 (Console_config.load ~path ()) in
  let updated = Console_config.upsert existing c in
  map_err 500 (Console_config.save ~path updated)

let handle_post_console st body =
  match upsert_console st body with
  | Ok () -> json_resp 200 (`Assoc [ ("ok", `Bool true) ])
  | Error (code, msg) -> err_resp code msg

let handle_post_run st body =
  let run =
    let* json = map_err 400 (Repo_io.Json_file.of_string body) in
    let* req = map_err 400 (Ui_hub.Ui_api.decode_launch json) in
    Ui_hub.Run_manager.spawn st req
  in
  match run with
  | Ok j -> json_resp 201 j
  | Error (code, msg) -> err_resp code msg

let handle_get_consoles st =
  let ext = Ui_hub.Run_manager.detect_external () in
  let path = Ui_hub.Run_manager.config_path st in
  match
    Ui_hub.Ui_api.consoles_json ~path
      ~active_run:(Ui_hub.Run_manager.active_for_console st ext)
      ()
  with
  | Ok j -> json_resp 200 j
  | Error e -> err_resp 500 e

let route st meth path body =
  Ui_hub.Run_manager.reap_all st;
  match (meth, path) with
  | "GET", ("/" | "/index.html") ->
      (200, "text/html; charset=utf-8", Ui_hub.Ui_page.html)
  | "GET", "/api/programs" -> json_resp 200 (Ui_hub.Ui_api.programs_json ())
  | "GET", "/api/devices" -> json_resp 200 (Ui_hub.Ui_api.devices_json ())
  | "GET", "/api/consoles" -> handle_get_consoles st
  | "POST", "/api/consoles" -> handle_post_console st body
  | "GET", "/api/runs" -> json_resp 200 (Ui_hub.Run_manager.all_runs_json st)
  | "POST", "/api/runs" -> handle_post_run st body
  | "POST", p when Ui_hub.Ui_api.stop_id_of_path p <> None -> (
      let id = Option.get (Ui_hub.Ui_api.stop_id_of_path p) in
      match Ui_hub.Run_manager.stop st id with
      | Ok j -> json_resp 200 j
      | Error (code, msg) -> err_resp code msg)
  | _ -> err_resp 404 ("not found: " ^ meth ^ " " ^ path)

let write_all fd text =
  let len = String.length text in
  let rec loop off =
    if off < len then
      let n = Unix.write_substring fd text off (len - off) in
      if n > 0 then loop (off + n)
  in
  loop 0

let handle_client st client =
  let buf = Bytes.create read_buf_size in
  let n = Unix.read client buf 0 read_buf_size in
  (if n > 0 then
     let raw = Bytes.sub_string buf 0 n in
     let code, ctype, body =
       match Ui_hub.Ui_api.split_http raw with
       | Some (meth, path, req_body) -> route st meth path req_body
       | None -> err_resp 400 "malformed HTTP request"
     in
     let resp =
       Printf.sprintf
         "HTTP/1.1 %d %s\r\n\
          Content-Type: %s\r\n\
          Content-Length: %d\r\n\
          Connection: close\r\n\
          \r\n\
          %s"
         code
         (Ui_hub.Ui_api.status_text code)
         ctype (String.length body) body
     in
     write_all client resp);
  Unix.close client

let serve (f : flags) =
  let config_path =
    Option.value f.config ~default:(Console_config.default_path ())
  in
  let st = Ui_hub.Run_manager.create ~config_path in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  let addr = Unix.inet_addr_of_string f.listen in
  Unix.bind sock (Unix.ADDR_INET (addr, f.port));
  Unix.listen sock backlog;
  Printf.printf "GamePilot Hub listening on http://%s:%d (config: %s)\n%!"
    f.listen f.port config_path;
  let running = ref true in
  let rec loop () =
    if !running then (
      Ui_hub.Run_manager.reap_all st;
      let ready, _, _ = Unix.select [ sock ] [] [] poll_timeout_s in
      (if ready <> [] then
         let client, _ = Unix.accept sock in
         handle_client st client);
      loop ())
    else 0
  in
  loop ()

let main args =
  let defaults =
    { port = default_port; listen = default_listen; config = None }
  in
  Result.map serve (parse defaults args)
