(* The daemon for one checkpoint run: started with its wire log in the run's
   folder, stopped (SIGTERM, which it handles by closing cleanly) after the
   run. One daemon per run gives each run its own wire log, which
   [gamepilot replay checkpoint] replays as it is. *)

type t = { pid : int; out_file : string }

let ready_line = "daemon: listening on"
let ready_timeout_s = 15.
let poll_interval_s = 0.1

let file_text path =
  match In_channel.with_open_bin path In_channel.input_all with
  | text -> text
  | exception Sys_error _ -> ""

let contains text part =
  let n = String.length part in
  let rec at i =
    i + n <= String.length text && (String.sub text i n = part || at (i + 1))
  in
  at 0

let exited pid =
  match Unix.waitpid [ Unix.WNOHANG ] pid with
  | 0, _ -> false
  | _ -> true
  | exception Unix.Unix_error (Unix.ECHILD, _, _) -> true

(* Waits for the daemon's "listening" line in its output file. *)
let rec wait_ready t deadline =
  let out = file_text t.out_file in
  if contains out ready_line then Ok t
  else if exited t.pid then Error ("the daemon exited: " ^ String.trim out)
  else if Unix.gettimeofday () > deadline then (
    Unix.kill t.pid Sys.sigterm;
    Error "the daemon did not start listening in 15 s")
  else (
    Unix.sleepf poll_interval_s;
    wait_ready t deadline)

let start ~daemon ~mgba_port ~port ~wire_log ~out_file =
  let args =
    [|
      daemon;
      "--backend";
      "mgba";
      "--mgba-port";
      string_of_int mgba_port;
      "--port";
      string_of_int port;
      "--log";
      wire_log;
    |]
  in
  let out =
    Unix.openfile out_file [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o644
  in
  match Unix.create_process daemon args Unix.stdin out out with
  | pid ->
      Unix.close out;
      wait_ready { pid; out_file } (Unix.gettimeofday () +. ready_timeout_s)
  | exception Unix.Unix_error (e, _, _) ->
      Unix.close out;
      Error (daemon ^ ": " ^ Unix.error_message e)

let stop t =
  (try Unix.kill t.pid Sys.sigterm with Unix.Unix_error _ -> ());
  try ignore (Unix.waitpid [] t.pid : int * Unix.process_status)
  with Unix.Unix_error _ -> ()
