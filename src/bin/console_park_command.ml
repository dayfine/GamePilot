(* gamepilot console park|resume --daemon PATH [--serial PORT]
     (--capture DEVICE | --replay VIDEO) [--log-dir DIR]
   gamepilot ctl [--port N] [--owner LABEL] park|resume

   Parks the Switch on its HOME menu, or resumes FireRed from there
   (Switch_home.Console_park). [console] starts a daemon of its own on the
   board and the card, as run/run_checkpoints_on_switch.sh does at its start
   and its release, with its wire log and output in --log-dir (the temp
   folder); [ctl park] and [ctl resume] use a running daemon (the idle one)
   under the input lease. Exit 1 when the console did not end where asked. *)

module P = Switch_home.Console_park

(* FireRed's tile on HOME: its orange background and Charizard, 0.41 of the
   art; the other tiles on console B 0.05 at most (2026-11-24). *)
let fire_red_tile : Switch_home.Home_screen.tile_color =
  { min = (200, 40, 0); max = (255, 170, 100) }

let client = "gamepilot-console/0.1"

let usage =
  "  gamepilot console park|resume --daemon PATH [--serial PORT] (--capture \
   DEVICE | --replay VIDEO) [--log-dir DIR]\n"

let log line = print_endline line

let park () =
  match P.park ~log fire_red_tile with
  | Ok () -> true
  | Error e ->
      log ("[Park] failed: " ^ e);
      false

let resume () =
  match P.resume ~log fire_red_tile with
  | Ok r ->
      log ("[Resume] " ^ P.resumed_to_string r);
      true
  | Error e ->
      log ("[Resume] failed: " ^ e);
      false

(* Park or resume in the effect context; whether it ended where asked. *)
let act = function `Park -> park () | `Resume -> resume ()
let owner = function `Park -> "console:park" | `Resume -> "console:resume"

let on_port ~port ~owner:o which =
  match Live.run ~port ~client ~lease:(o, None) (fun () -> act which) with
  | true -> 0
  | false -> 1
  | exception Unix.Unix_error (e, _, _) ->
      log ("no daemon: " ^ Unix.error_message e);
      1

(* A daemon of its own on the board and the card for the step. *)
let with_daemon ~daemon ~serial ~frames ~log_dir which =
  let name = match which with `Park -> "park" | `Resume -> "resume" in
  let file ext = Filename.concat log_dir ("gamepilot-" ^ name ^ ext) in
  match
    Daemon_process.start ~daemon
      ~backend:(Daemon_process.Switch { serial; frames })
      ~port:0 ~wire_log:(file ".wire.jsonl") ~out_file:(file ".daemon.out")
      ~checkpoint:name ()
  with
  | Error e ->
      log ("[Console] no daemon: " ^ e);
      1
  | Ok d ->
      Fun.protect
        ~finally:(fun () -> Daemon_process.stop d)
        (fun () -> on_port ~port:d.port ~owner:(owner which) which)

type flags = {
  daemon : string;
  serial : string option;
  frames : Daemon_process.frames option;
  log_dir : string;
}

let rec parse f = function
  | [] -> Ok f
  | "--daemon" :: v :: rest -> parse { f with daemon = v } rest
  | "--serial" :: v :: rest -> parse { f with serial = Some v } rest
  | "--capture" :: v :: rest ->
      parse { f with frames = Some (Daemon_process.Capture v) } rest
  | "--replay" :: v :: rest ->
      parse { f with frames = Some (Daemon_process.Replay v) } rest
  | "--log-dir" :: v :: rest -> parse { f with log_dir = v } rest
  | a :: _ -> Error ("unknown argument " ^ a)

let main args =
  let which, flags =
    match args with
    | "park" :: flags -> (Some `Park, flags)
    | "resume" :: flags -> (Some `Resume, flags)
    | flags -> (None, flags)
  in
  let defaults =
    {
      daemon = "daemon/build/gamepilot_daemon";
      serial = None;
      frames = None;
      log_dir = Filename.get_temp_dir_name ();
    }
  in
  match (which, parse defaults flags) with
  | None, _ -> Error ("console: park or resume\n" ^ usage)
  | _, Error e -> Error e
  | Some _, Ok { frames = None; _ } ->
      Error "--capture DEVICE or --replay VIDEO is required"
  | Some which, Ok ({ frames = Some frames; _ } as f) ->
      Ok
        (with_daemon ~daemon:f.daemon ~serial:f.serial ~frames
           ~log_dir:f.log_dir which)
