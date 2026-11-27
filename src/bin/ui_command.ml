(* gamepilot ui [--port N] [--listen ADDR] [--config FILE]
   Local HTTP control hub (docs/design/Release-and-Onboarding.md): binds a
   localhost TCP socket and dispatches HTTP requests to Ui_hub.Http_router. *)

let usage = "  gamepilot ui [--port N] [--listen ADDR] [--config FILE]\n"
let default_port = 47902
let default_listen = "127.0.0.1"
let read_buf_size = 8192
let poll_timeout_s = 0.25
let backlog = 16
let http_bad_request = 400

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

let write_all fd text =
  let len = String.length text in
  let rec loop off =
    if off < len then
      let n = Unix.write_substring fd text off (len - off) in
      if n > 0 then loop (off + n)
  in
  loop 0

let dispatch_raw st raw =
  let code, ctype, body =
    match Ui_hub.Ui_api.split_http raw with
    | Some (meth, path, req_body) ->
        Ui_hub.Http_router.route st meth path req_body
    | None ->
        ( http_bad_request,
          "application/json; charset=utf-8",
          "{\"error\":\"malformed HTTP request\"}" )
  in
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

let handle_client st client =
  let buf = Bytes.create read_buf_size in
  let n = Unix.read client buf 0 read_buf_size in
  if n > 0 then write_all client (dispatch_raw st (Bytes.sub_string buf 0 n));
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
