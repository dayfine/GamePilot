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
  "  gamepilot console park|resume --daemon PATH [--serial PORT] (--capture \
   DEVICE | --replay VIDEO) [--log-dir DIR]\n"

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
