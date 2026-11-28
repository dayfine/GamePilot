(* The daemon for one checkpoint run: started with its wire log in the run's
   folder, stopped (SIGTERM, which it handles by closing cleanly) after the
   run. One daemon per run gives each run its own wire log, which
   [gamepilot replay checkpoint] replays as it is. Port 0 lets the daemon pick
   a free one; [t] has the ports it bound, read from its output. *)

type t = {
  pid : int;
  out_file : string;
  port : int;  (** the program's, as bound *)
  watch_port : int option;  (** the watch page's, as bound *)
}

(** Where the Switch's frames come from: the capture card, or a recorded video
    (a dry run). *)
type frames = Capture of string | Replay of string

(** What the daemon drives: mGBA through its bridge, or the Switch through the
    controller board's serial port and the capture card (names as
    [gamepilot switch-devices] prints them). With no serial port the daemon
    sends the presses to its fake board: a dry run. *)
type backend =
  | Mgba of { port : int }
  | Switch of { serial : string option; frames : frames }

(* rw-r--r--: the daemon's output file. *)
let out_perm = 0o644

let frames_args = function
  | Capture device -> [ "--capture"; device ]
  | Replay video -> [ "--replay"; video ]

(* The Switch daemon's --viewport, when there is one; mGBA's frame is the
   picture. *)
let viewport_args backend viewport =
  match (backend, viewport) with
  | Switch _, Some v -> [ "--viewport"; v ]
  | Switch _, None | Mgba _, _ -> []

let backend_args = function
  | Mgba { port } -> [ "--backend"; "mgba"; "--mgba-port"; string_of_int port ]
  | Switch { serial; frames } ->
      [ "--backend"; "switch" ]
      @ Option.fold ~none:[] ~some:(fun s -> [ "--serial"; s ]) serial
      @ frames_args frames

type watch = {
  listen : string;
      (** The address it binds: [127.0.0.1] unless the user opened it to the
          LAN. *)
  port : int;  (** 0: any free port. *)
  token : string;  (** Stop's (Watch_urls.new_token), the same for a series. *)
  registry : string;  (** The watch registry folder ($GAMEPILOT_RUNS/.watch). *)
}

let flag_pairs pairs = List.concat_map (fun (name, v) -> [ name; v ]) pairs

let page_flags ~checkpoint w =
  [
    ("--watch-port", string_of_int w.port);
    ("--listen", w.listen);
    ("--watch-token", w.token);
    ("--registry", w.registry);
    ("--checkpoint", checkpoint);
  ]

let watch_args ~checkpoint watch =
  Option.fold ~none:[]
    ~some:(fun w -> flag_pairs (page_flags ~checkpoint w))
    watch

let ready_line = "daemon: listening on"
let watch_line = "daemon: watch page on http://"
let ready_timeout_s = 15.
let poll_interval_s = 0.1

let file_text path =
  match In_channel.with_open_bin path In_channel.input_all with
  | text -> text
  | exception Sys_error _ -> ""

let is_digit c = c >= '0' && c <= '9'

(* The port after the last ':' on [prefix]'s line: "...127.0.0.1:47950". *)
let port_after text prefix =
  let ( let* ) = Option.bind in
  let* i = Strings.Find.substring text prefix in
  let line_end =
    Option.value
      (String.index_from_opt text i '\n')
      ~default:(String.length text)
  in
  let line = String.sub text i (line_end - i) in
  let* colon = String.rindex_opt line ':' in
  let rest = String.sub line (colon + 1) (String.length line - colon - 1) in
  int_of_string_opt
    (String.of_seq (Seq.take_while is_digit (String.to_seq rest)))

let exited pid =
  match Unix.waitpid [ Unix.WNOHANG ] pid with
  | 0, _ -> false
  | _ -> true
  | exception Unix.Unix_error (Unix.ECHILD, _, _) -> true

(* Waits for the daemon's "listening" line in its output file. *)
let rec wait_ready t deadline =
  let out = file_text t.out_file in
  if Strings.Contains.substring out ready_line then
    match port_after out ready_line with
    | Some port -> Ok { t with port; watch_port = port_after out watch_line }
    | None -> Error ("the daemon gave no port: " ^ String.trim out)
  else if exited t.pid then Error ("the daemon exited: " ^ String.trim out)
  else if Unix.gettimeofday () > deadline then (
    Unix.kill t.pid Sys.sigterm;
    Error "the daemon did not start listening in 15 s")
  else (
    Unix.sleepf poll_interval_s;
    wait_ready t deadline)

(* The run folder always: the daemon keeps the run's notes there and, when
   recording, its frames (Watch-Page.md, Past runs). [flags] are the user's
   --record, --no-record and --keepawake, as given. *)
let start ?watch ?(flags = []) ~daemon ~backend ~port ~wire_log ~out_file
    ~checkpoint () =
  let args =
    Array.of_list
      ((daemon :: backend_args backend)
      @ [ "--port"; string_of_int port; "--log"; wire_log ]
      @ [ "--run-folder"; Filename.dirname out_file ]
      @ watch_args ~checkpoint watch
      @ flags)
  in
  let out =
    Unix.openfile out_file
      [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ]
      out_perm
  in
  match Unix.create_process daemon args Unix.stdin out out with
  | pid ->
      Unix.close out;
      wait_ready
        { pid; out_file; port; watch_port = None }
        (Unix.gettimeofday () +. ready_timeout_s)
  | exception Unix.Unix_error (e, _, _) ->
      Unix.close out;
      Error (daemon ^ ": " ^ Unix.error_message e)

let stop t =
  (try Unix.kill t.pid Sys.sigterm with Unix.Unix_error _ -> ());
  try ignore (Unix.waitpid [] t.pid : int * Unix.process_status)
  with Unix.Unix_error _ -> ()

let sleep_quietly s =
  try Unix.sleepf s with Unix.Unix_error (Unix.EINTR, _, _) -> ()

let wait t =
  let running = ref true in
  let on_sig _ = running := false in
  let prev_int = Sys.signal Sys.sigint (Sys.Signal_handle on_sig) in
  let prev_term =
    if Sys.win32 then Sys.Signal_default
    else Sys.signal Sys.sigterm (Sys.Signal_handle on_sig)
  in
  let restore () =
    Sys.set_signal Sys.sigint prev_int;
    if not Sys.win32 then Sys.set_signal Sys.sigterm prev_term
  in
  Fun.protect ~finally:restore (fun () ->
      while !running && not (exited t.pid) do
        sleep_quietly poll_interval_s
      done;
      if not (exited t.pid) then stop t)
