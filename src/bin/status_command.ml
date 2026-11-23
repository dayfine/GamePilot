(* gamepilot status [--port N]

   Asks a running daemon for its health ([status], contracts v1.5) and prints
   it: per thread its last frame and how long ago it showed life, marked STUCK
   past Wire.Daemon_status.stuck_limit_ms; the capture ring; gaps; the client.
   It connects as an observer, so it works while a program is connected.
   Exit code 0 when nothing is stuck, 1 when something is. *)

let usage = "  gamepilot status [--port N]\n"
let request = {|{"jsonrpc":"2.0","id":1,"method":"status","params":{}}|}

(* Sends one request line and reads one reply line. *)
let ask port =
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      Unix.connect fd (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
      let out = Unix.out_channel_of_descr fd in
      output_string out (request ^ "\n");
      flush out;
      input_line (Unix.in_channel_of_descr fd))

let thread_line (s : Wire.Daemon_status.t) (th : Wire.Daemon_status.thread) =
  let age = Wire.Daemon_status.age_ms s th in
  let verdict =
    if age > Wire.Daemon_status.stuck_limit_ms then
      Printf.sprintf "STUCK (limit %.0f ms)" Wire.Daemon_status.stuck_limit_ms
    else "ok"
  in
  Printf.sprintf "  %-8s seq %d, %.0f ms ago: %s" th.name th.seq age verdict

let report (s : Wire.Daemon_status.t) =
  Printf.printf "daemon: %s backend, client %s, fidelity %s\n" s.backend
    (Option.value s.client ~default:"none")
    s.fidelity;
  List.iter (fun th -> print_endline (thread_line s th)) s.threads;
  Printf.printf "  ring %d/%d, gaps %d (%d frames)\n" s.ring_depth
    s.ring_capacity s.gaps s.gap_frames

let status_of_reply line =
  match Wire.message_of_string line with
  | Wire.Response { outcome = Ok result; _ } ->
      Ok (Wire.Daemon_status.of_json result)
  | Wire.Response { outcome = Error e; _ } -> Error ("daemon: " ^ e.message)
  | _ -> Error "daemon: unexpected reply"
  | exception Wire.Decode_error e -> Error ("daemon: " ^ e)

(* Prints the daemon's status; 0 when nothing is stuck, 1 when something is. *)
let show port =
  match status_of_reply (ask port) with
  | Error e -> Error e
  | Ok s ->
      report s;
      Ok (if Wire.Daemon_status.stuck s = [] then 0 else 1)
  | exception Unix.Unix_error (e, _, _) ->
      Error
        (Printf.sprintf "no daemon on port %d: %s" port (Unix.error_message e))

let main = function
  | [] -> show Live.default_port
  | [ "--port"; p ] -> (
      match int_of_string_opt p with
      | Some port -> show port
      | None -> Error ("bad --port " ^ p))
  | a :: _ -> Error ("unknown argument " ^ a)
