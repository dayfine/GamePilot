(* gamepilot console park|resume --daemon PATH [--serial PORT]
     (--capture DEVICE | --replay VIDEO) [--log-dir DIR]
   gamepilot ctl [--port N] [--owner LABEL] park|resume

   Parks the Switch on its HOME menu, or resumes the lab console's game from
   there (Switch.Console_park; the game's tile:
   Program_registry.lab_game_of_env). [console] starts a daemon of its own on
   the board and the card, as run/run_checkpoints_on_switch.sh does at its
   start and its release, with its wire log and output in --log-dir (the temp
   folder); [ctl park] and [ctl resume] use a running daemon (the idle one)
   under the input lease. Exit 1 when the console did not end where asked. *)

module P = Switch.Console_park

let client = "gamepilot-console/0.1"

let usage =
  "  gamepilot console watch [--console ID] [--port N] [--watch-port N] \
   [--listen ADDR] [--runs-dir DIR] [--daemon PATH] [--log-dir DIR] [--config \
   FILE]\n\
  \  gamepilot console park|resume [--console ID] [--daemon PATH] [--serial \
   PORT] (--capture DEVICE | --replay VIDEO) [--runs-dir DIR] [--watch-port N] \
   [--listen ADDR] [--log-dir DIR] [--config FILE]\n"

let log line = print_endline line

let park ~tile ~picture =
  match P.park ~log ~picture tile with
  | Ok () -> true
  | Error e ->
      log ("[Park] failed: " ^ e);
      false

let resume ~tile ~picture =
  match P.resume ~log ~picture tile with
  | Ok r ->
      log ("[Resume] " ^ P.resumed_to_string r);
      true
  | Error e ->
      log ("[Resume] failed: " ^ e);
      false

(* Switch.Game_entry's steps, the game's tile colour for the HOME
   reader. *)
let entry_step name result =
  match result with
  | Ok () ->
      log ("[" ^ name ^ "] done");
      true
  | Error e ->
      log ("[" ^ name ^ "] failed: " ^ e);
      false

let close_game ~tile ~picture =
  entry_step "Close game" (Switch.Game_entry.close_game ~log ~picture tile)

let start_game ~tile ~picture slot =
  entry_step "Start game"
    (Switch.Game_entry.start_game ~log ~picture ~game_slot:slot ~user_slot:0
       tile)

(* Switch.Delete_save's two steps (Delete_save_command). *)
let delete_save ~tile ~picture game =
  entry_step "Delete save"
    (Switch.Delete_save.to_caution ~log ~picture tile game)

let delete_save_confirm ~picture =
  entry_step "Delete save, confirm" (Switch.Delete_save.confirm ~log ~picture)

(* Park, resume, close, start or delete a save in the effect context, over the
   game picture the daemon's hello reports; whether it ended where asked. *)
let act ~tile which (backend : Wire.backend) =
  let picture = backend.viewport in
  match which with
  | `Park -> park ~tile ~picture
  | `Resume -> resume ~tile ~picture
  | `Close_game -> close_game ~tile ~picture
  | `Start_game slot -> start_game ~tile ~picture slot
  | `Delete_save game -> delete_save ~tile ~picture game
  | `Delete_save_confirm -> delete_save_confirm ~picture

let name = function
  | `Park -> "park"
  | `Resume -> "resume"
  | `Close_game -> "close-game"
  | `Start_game _ -> "start-game"
  | `Delete_save _ -> "delete-save"
  | `Delete_save_confirm -> "delete-save-confirm"

let owner which = "console:" ^ name which

(* The step on the daemon at [port] for the game's tile. *)
let on_tile ~port ~owner:o which tile =
  match
    Live.run_with_backend ~port ~client ~lease:(o, None) (act ~tile which)
  with
  | true -> 0
  | false -> 1
  | exception Unix.Unix_error (e, _, _) ->
      log ("no daemon: " ^ Unix.error_message e);
      1

(* The step for the lab console's game (Program_registry.lab_game_of_env). *)
let on_port ~port ~owner which =
  match Program_registry.lab_game_of_env () with
  | Error e ->
      log ("[Console] " ^ e);
      1
  | Ok (_, home) -> on_tile ~port ~owner which home.home_tile

(* A daemon of its own on the board and the card for the step. *)
let with_daemon ~daemon ~serial ~frames ~log_dir which =
  let name = name which in
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
  console : string option;
  serial : string option;
  frames : Daemon_process.frames option;
  session : Console_session.options;
}

let parse_int ~flag v =
  match int_of_string_opt v with
  | Some n when n >= 0 -> Ok n
  | _ -> Error ("bad " ^ flag ^ " " ^ v)

let rec parse f = function
  | [] -> Ok f
  | "--console" :: v :: rest -> parse { f with console = Some v } rest
  | "--daemon" :: v :: rest ->
      parse { f with session = { f.session with daemon = v } } rest
  | "--serial" :: v :: rest -> parse { f with serial = Some v } rest
  | "--capture" :: v :: rest ->
      parse { f with frames = Some (Daemon_process.Capture v) } rest
  | "--replay" :: v :: rest ->
      parse { f with frames = Some (Daemon_process.Replay v) } rest
  | "--log-dir" :: v :: rest ->
      parse { f with session = { f.session with log_dir = v } } rest
  | "--runs-dir" :: v :: rest ->
      parse { f with session = { f.session with runs_dir = v } } rest
  | "--config" :: v :: rest ->
      parse { f with session = { f.session with config = Some v } } rest
  | "--listen" :: v :: rest ->
      parse { f with session = { f.session with listen = Some v } } rest
  | "--port" :: v :: rest ->
      Result.bind (parse_int ~flag:"--port" v) (fun port ->
          parse { f with session = { f.session with port } } rest)
  | "--watch-port" :: v :: rest ->
      Result.bind (parse_int ~flag:"--watch-port" v) (fun p ->
          parse { f with session = { f.session with watch_port = Some p } } rest)
  | a :: _ -> Error ("unknown argument " ^ a)

let run_park_or_resume which f =
  match (f.console, f.frames) with
  | Some id, None ->
      Console_session.with_console f.session ~console_id:(Some id)
        ~checkpoint:(name which) (fun d ->
          on_port ~port:d.port ~owner:(owner which) which)
  | _, Some frames ->
      Ok
        (with_daemon ~daemon:f.session.daemon ~serial:f.serial ~frames
           ~log_dir:f.session.log_dir which)
  | None, None ->
      Error "--console ID, --capture DEVICE, or --replay VIDEO is required"

let main args =
  let which, default_port, flags =
    match args with
    | "watch" :: flags -> (Some `Watch, Live.default_port, flags)
    | "park" :: flags -> (Some `Park, 0, flags)
    | "resume" :: flags -> (Some `Resume, 0, flags)
    | flags -> (None, 0, flags)
  in
  let defaults =
    {
      console = None;
      serial = None;
      frames = None;
      session = Console_session.defaults ~port:default_port ();
    }
  in
  match (which, parse defaults flags) with
  | None, _ -> Error ("console: watch, park or resume\n" ^ usage)
  | _, Error e -> Error e
  | Some `Watch, Ok f ->
      Console_session.watch_console f.session ~console_id:f.console
  | Some ((`Park | `Resume) as w), Ok f -> run_park_or_resume w f

(* A step of another ctl command under the lease, as the ones above: in the
   effect context over the hello's game picture, its log lines printed and on
   the watch page; 0 when it ended where asked, else 1 with its error
   (Home_boxes_command). *)
let watched_log line =
  log line;
  Effects.show_log line

let run_step ~port ~owner ~name step =
  let act (backend : Wire.backend) =
    entry_step name (step ~log:watched_log ~picture:backend.viewport)
  in
  match Live.run_with_backend ~port ~client ~lease:(owner, None) act with
  | true -> 0
  | false -> 1
  | exception Unix.Unix_error (e, _, _) ->
      log ("no daemon: " ^ Unix.error_message e);
      1
