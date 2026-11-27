(* gamepilot run's flags, whatever the game: their record, defaults and
   parsing, with a game's own flags ('game) parsed by the game's hooks. *)

open Engine_run

type 'game flags = {
  from_id : string option;
  to_id : string option;
  mode : Checkpoint_trials.mode option;
  runs : int option;
  states : string;
  runs_dir : string;
  daemon : string;
  mgba_port : int;
  backend : string;  (** mgba or switch *)
  serial : string option;
  capture : string option;
  replay : string option;  (** A recorded video for a dry run (fake board). *)
  save_after_pass : bool;  (** Switch: save in the game after a pass. *)
  close_game : bool;
      (** Switch: return to HOME and close the running game after a passing
          series ([--close-game]); false by default. *)
  preflight : bool;
  max_rounds : int option;  (** A repeating checkpoint's rounds, at most. *)
  from_event : string option;
      (** mGBA, testing: run from this event's kept state
          (Engine_run.Event_range). *)
  to_event : string option;  (** ... to this event (else the last). *)
  port : int;  (** The program's port; 0: any free one. *)
  watch : Daemon_process.watch option;
  viewport : string option;
      (** --viewport V: the Switch daemons' game picture; only for a plan folder
          no program registers, else it must match the program's
          (Program_registry.check_viewport). *)
  daemon_flags : string list;
      (** --record, --no-record, --keepawake N, --speed S: passed to each run's
          daemon. *)
  options : (string * string) list;
      (** --options KEY=VALUE, one pair each, repeatable: the program's own
          choices in the order given; [[]] when none. The program's registry
          entry declares the keys it takes (Program_registry.check_options). *)
  game : 'game;  (** The game's own flags. *)
}

type 'game valued_flag = Not_game_flag | Bad_value of string | Parsed of 'game

type 'game game_flags = {
  game_defaults : 'game;
  game_switch : 'game -> string -> 'game option;
  game_valued : 'game -> string -> string -> 'game valued_flag;
}

(* [var] from the environment, else [$HOME/.local/share/gamepilot/<name>]. *)
let data_dir = Repo_io.Repo_files.data_dir
let mgba_bridge_port = 47810

let defaults game =
  {
    from_id = None;
    to_id = None;
    mode = None;
    runs = None;
    states = data_dir "GAMEPILOT_STATES" "states";
    runs_dir = data_dir "GAMEPILOT_RUNS" "runs";
    daemon = Repo_io.Repo_files.default_daemon ();
    mgba_port = mgba_bridge_port;
    backend = "mgba";
    serial = None;
    capture = None;
    replay = None;
    save_after_pass = true;
    close_game = false;
    preflight = false;
    max_rounds = None;
    from_event = None;
    to_event = None;
    port = 0;
    watch = None;
    viewport = None;
    daemon_flags = [];
    options = [];
    game = game.game_defaults;
  }

(* A flag with an int value: [set] applies it. *)
let int_flag name text set =
  match int_of_string_opt text with
  | Some n -> Ok (set n)
  | None -> Error ("bad " ^ name ^ " " ^ text)

let mode_flag f m =
  match Checkpoint_trials.mode_of_string m with
  | Some mode -> Ok { f with mode = Some mode }
  | None -> Error ("bad --mode " ^ m)

(* mGBA only (the daemon refuses it on a live backend): the daemon steps the
   emulator S times its frame rate; the program's times stay game time
   (protocol/v1/README.md). *)
let speed_flag f text =
  match float_of_string_opt text with
  | Some s when s > 0. ->
      Ok { f with daemon_flags = f.daemon_flags @ [ "--speed"; text ] }
  | _ -> Error ("bad --speed " ^ text)

let keepawake_flag f seconds =
  {
    f with
    daemon_flags = f.daemon_flags @ [ "--keepawake"; string_of_int seconds ];
  }

(* --options KEY=VALUE: one more pair, its syntax checked; the keys are the
   program's to check. *)
let options_flag f text =
  Result.map
    (fun pair -> { f with options = f.options @ [ pair ] })
    (Run_options.pair text)

(* One flag with its value, or [None] for a flag that takes none or an
   unknown one. *)
let valued f name v =
  match name with
  | "--from" -> Some (Ok { f with from_id = Some v })
  | "--to" -> Some (Ok { f with to_id = Some v })
  | "--mode" -> Some (mode_flag f v)
  | "--runs" -> Some (int_flag name v (fun n -> { f with runs = Some n }))
  | "--states" -> Some (Ok { f with states = v })
  | "--runs-dir" -> Some (Ok { f with runs_dir = v })
  | "--daemon" -> Some (Ok { f with daemon = v })
  | "--mgba-port" ->
      Some (int_flag name v (fun mgba_port -> { f with mgba_port }))
  | "--port" -> Some (int_flag name v (fun port -> { f with port }))
  | "--backend" -> Some (Ok { f with backend = v })
  | "--serial" -> Some (Ok { f with serial = Some v })
  | "--capture" -> Some (Ok { f with capture = Some v })
  | "--replay" -> Some (Ok { f with replay = Some v })
  | "--max-rounds" -> (
      match int_of_string_opt v with
      | Some n when n > 0 -> Some (Ok { f with max_rounds = Some n })
      | _ -> Some (Error ("bad --max-rounds " ^ v)))
  | "--from-event" -> Some (Ok { f with from_event = Some v })
  | "--to-event" -> Some (Ok { f with to_event = Some v })
  | "--keepawake" -> Some (int_flag name v (keepawake_flag f))
  | "--speed" -> Some (speed_flag f v)
  | "--viewport" -> Some (Ok { f with viewport = Some v })
  | "--options" -> Some (options_flag f v)
  | _ -> None

(* The page by default: on a free port, $GAMEPILOT_WATCH_LISTEN or this machine
   only, a new token, the registry beside the runs. *)
let default_watch runs_dir =
  {
    Daemon_process.listen = Watch_urls.default_listen ();
    port = 0;
    token = Watch_urls.new_token ();
    registry = Filename.concat runs_dir ".watch";
  }

(* --watch-port and --listen imply --watch. *)
let watch_flag f set =
  let w = Option.value f.watch ~default:(default_watch f.runs_dir) in
  { f with watch = Some (set w) }

let watch_port f port = watch_flag f (fun w -> { w with Daemon_process.port })

let watch_valued f name v =
  match name with
  | "--watch-port" -> Some (int_flag name v (watch_port f))
  | "--listen" -> Some (Ok (watch_flag f (fun w -> { w with listen = v })))
  | _ -> None

(* The game's flag with its value. *)
let game_valued game f name v =
  match game.game_valued f.game name v with
  | Not_game_flag -> None
  | Bad_value e -> Some (Error e)
  | Parsed g -> Some (Ok { f with game = g })

let valued game f name v =
  match watch_valued f name v with
  | Some r -> Some r
  | None -> (
      match valued f name v with
      | Some r -> Some r
      | None -> game_valued game f name v)

let rec parse game f = function
  | [] -> Ok f
  | "--watch" :: rest -> parse game (watch_flag f Fun.id) rest
  | "--save-after-pass" :: rest ->
      parse game { f with save_after_pass = true } rest
  | "--no-save-after-pass" :: rest ->
      parse game { f with save_after_pass = false } rest
  | "--close-game" :: rest -> parse game { f with close_game = true } rest
  | "--preflight" :: rest -> parse game { f with preflight = true } rest
  | (("--record" | "--no-record") as flag) :: rest ->
      parse game { f with daemon_flags = f.daemon_flags @ [ flag ] } rest
  | name :: rest when Option.is_some (game.game_switch f.game name) ->
      parse game
        { f with game = Option.get (game.game_switch f.game name) }
        rest
  | name :: v :: rest when Option.is_some (valued game f name v) ->
      Result.bind
        (Option.get (valued game f name v))
        (fun f -> parse game f rest)
  | a :: _ -> Error ("unknown argument " ^ a)

let required name = function
  | Some v -> Ok v
  | None -> Error (name ^ " is required")

(* The daemon's backend from the flags; the Switch only in testing mode. *)
let daemon_backend f mode =
  match (f.backend, f.serial, f.capture, f.replay, mode) with
  | "mgba", None, None, None, _ ->
      if f.close_game then Error "--close-game needs --backend switch"
      else Ok (Daemon_process.Mgba { port = f.mgba_port })
  | "mgba", _, _, _, _ ->
      Error "--serial, --capture and --replay need --backend switch"
  | "switch", _, _, _, Checkpoint_trials.Verification ->
      Error "--backend switch runs only --mode testing"
  | "switch", Some serial, Some capture, None, Testing ->
      Ok
        (Daemon_process.Switch
           { serial = Some serial; frames = Capture capture })
  | "switch", None, None, Some video, Testing ->
      Ok (Daemon_process.Switch { serial = None; frames = Replay video })
  | "switch", _, _, _, _ ->
      Error
        "--backend switch needs --serial and --capture, or --replay alone (a \
         dry run on the fake board)"
  | b, _, _, _, _ -> Error ("bad --backend " ^ b)

let no_game_flags : unit game_flags =
  {
    game_defaults = ();
    game_switch = (fun () _ -> None);
    game_valued = (fun () _ _ -> Not_game_flag);
  }

let parse_no_game_flags args = parse no_game_flags (defaults no_game_flags) args

let require_testing_only ~game f =
  let refused =
    List.filter_map
      (fun (given, flag) -> if given then Some flag else None)
      [
        (f.mode <> None && f.mode <> Some Checkpoint_trials.Testing, "--mode");
        (f.preflight, "--preflight");
        (f.from_event <> None, "--from-event");
        (f.to_event <> None, "--to-event");
        (f.max_rounds <> None, "--max-rounds");
      ]
  in
  match refused with
  | [] -> Ok ()
  | flags ->
      Error
        (game ^ " runs whole checkpoints in testing mode only: no "
       ^ String.concat ", " flags)

let require_switch ~game = function
  | Daemon_process.Mgba _ ->
      Error (game ^ " runs on the Switch only: --backend switch")
  | Daemon_process.Switch _ -> Ok ()

let run_info ?(kind = Run_record.Checkpoints) ~program ~from_id ~to_id ~options
    f : Run_record.info =
  {
    kind;
    program;
    from_id;
    to_id;
    backend = f.backend;
    options = Run_options.pairs options;
  }
