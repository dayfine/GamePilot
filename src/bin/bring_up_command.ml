(* gamepilot bring-up [--daemon PATH] [--serial PORT] (--capture DEVICE |
     --replay VIDEO) [--runs-dir DIR]

   The Switch's bring-up checks (docs/switch-bring-up.md) as a run of their
   own: the daemon's --board-check (the board's mode) and --capture-check (one
   frame and where the GBA picture sits), each run to its end, in a run folder
   (<date>-switch-bring-up-<n>, Run_record) with run.json (kind bring-up),
   both checks' output in daemon.out, the frame (frame.png, also
   $GAMEPILOT_RUNS/bring-up-frame.png), summary.txt and the RESULTS.tsv row.
   A failed capture check keeps its frame as failure.png. Without --serial the
   board check runs on the daemon's fake board; --replay in place of
   --capture checks a video's first frame: a dry run
   (tools/run_checkpoints_on_switch.sh). Exit 1 when a check fails. *)

type flags = {
  daemon : string;
  serial : string option;
  frames : Daemon_process.frames option;
  runs_dir : string;
}

let usage =
  "  gamepilot bring-up [--daemon PATH] [--serial PORT] (--capture DEVICE | \
   --replay VIDEO) [--runs-dir DIR]\n"

let rec parse f = function
  | [] -> Ok f
  | "--daemon" :: v :: rest -> parse { f with daemon = v } rest
  | "--serial" :: v :: rest -> parse { f with serial = Some v } rest
  | "--capture" :: v :: rest ->
      parse { f with frames = Some (Daemon_process.Capture v) } rest
  | "--replay" :: v :: rest ->
      parse { f with frames = Some (Daemon_process.Replay v) } rest
  | "--runs-dir" :: v :: rest -> parse { f with runs_dir = v } rest
  | a :: _ -> Error ("unknown argument " ^ a)

(* One check: the daemon run to its end, its output appended to [out];
   whether it exited 0. *)
let check ~daemon ~out args =
  print_endline ("[Bring-up] " ^ String.concat " " args);
  let fd =
    Unix.openfile out [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_APPEND ] 0o644
  in
  let argv = Array.of_list (daemon :: "--backend" :: "switch" :: args) in
  let status =
    match Unix.create_process daemon argv Unix.stdin fd fd with
    | pid -> snd (Unix.waitpid [] pid)
    | exception Unix.Unix_error (e, _, _) ->
        prerr_endline (daemon ^ ": " ^ Unix.error_message e);
        Unix.WEXITED 127
  in
  Unix.close fd;
  status = Unix.WEXITED 0

let ending ~board ~capture : Run_record.ending =
  match (board, capture) with
  | true, true -> { result = "pass"; at = ""; reason = "" }
  | false, _ ->
      { result = "fail"; at = "board"; reason = "the board check failed" }
  | true, false ->
      { result = "fail"; at = "capture"; reason = "the capture check failed" }

let summary (e : Run_record.ending) =
  if e.result = "pass" then "PASS bring-up: the board and one frame"
  else Printf.sprintf "FAIL bring-up at %s: %s (daemon.out)" e.at e.reason

let keep_frame (run : Run_record.run) ~runs_dir ~passed =
  let frame = Run_record.path run.record "frame.png" in
  if Sys.file_exists frame then (
    Run_record.copy_file ~src:frame
      ~dst:(Filename.concat runs_dir "bring-up-frame.png");
    if not passed then
      Run_record.copy_file ~src:frame
        ~dst:(Run_record.path run.record "failure.png"))

let run f frames =
  let info : Run_record.info =
    {
      kind = Bring_up;
      program = [];
      from_id = "";
      to_id = "";
      backend = "switch";
    }
  in
  let run =
    Run_record.start ~runs_dir:f.runs_dir info ~checkpoint:"switch"
      ~mode:"bring-up"
  in
  let out = Run_record.path run.record "daemon.out" in
  print_endline ("[Bring-up] " ^ run.record.dir);
  let serial =
    Option.fold ~none:[] ~some:(fun s -> [ "--serial"; s ]) f.serial
  in
  let board = check ~daemon:f.daemon ~out (serial @ [ "--board-check" ]) in
  let capture =
    board
    && check ~daemon:f.daemon ~out
         (Daemon_process.frames_args frames
         @ [ "--capture-check"; Run_record.path run.record "frame.png" ])
  in
  let e = ending ~board ~capture in
  keep_frame run ~runs_dir:f.runs_dir ~passed:(e.result = "pass");
  print_endline ("[Bring-up] " ^ summary e);
  Run_record.finish ~runs_dir:f.runs_dir run ~summary:(summary e) e;
  if e.result = "pass" then 0 else 1

let main args =
  let defaults =
    {
      daemon = "daemon/build/gamepilot_daemon";
      serial = None;
      frames = None;
      runs_dir = Attached_run.default_runs_dir ();
    }
  in
  Result.bind (parse defaults args) (fun f ->
      match f.frames with
      | Some frames -> Ok (run f frames)
      | None -> Error "--capture DEVICE or --replay VIDEO is required")
