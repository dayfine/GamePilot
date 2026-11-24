(* gamepilot checkpoints' flags: their record, defaults and parsing
   (Checkpoints_command). *)

open Story

type flags = {
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
  preflight : bool;
  make_room : string option;  (** The save's map: room first (mg-00). *)
  max_rounds : int option;  (** A repeating checkpoint's rounds, at most. *)
  common : Checkpoint_command.flags;
  watch : Daemon_process.watch option;
  daemon_flags : string list;
      (** --record, --no-record, --keepawake N: passed to each run's daemon. *)
}

let usage =
  "  gamepilot checkpoints PLAN_DIR|--program ID --from ID --to ID --mode \
   testing|verification\n\
  \      [--runs N] [--states DIR] [--runs-dir DIR] [--daemon PATH]\n\
  \      [--mgba-port N] [--port N] [--party SPECIES,...] [--center TOWN] \
   [--walk]\n\
  \      [--end-check-only] [--grind-battles N] [--max-rounds N] [--watch]\n\
  \      [--watch-port N] [--listen ADDR]\n\
  \      [--backend mgba|switch --serial PORT --capture DEVICE]\n\
  \      [--replay VIDEO] [--save-after-pass|--no-save-after-pass]\n\
  \      [--record|--no-record] [--keepawake SECONDS] [--make-room MAP]\n\
  \  gamepilot checkpoints PLAN_DIR|--program ID --preflight --from ID \
   [--backend ...]\n"

let home = Option.value (Sys.getenv_opt "HOME") ~default:"."

(* [var] from the environment, else [$HOME/.local/share/gamepilot/<name>]. *)
let data_dir var name =
  match Sys.getenv_opt var with
  | Some dir when dir <> "" -> dir
  | _ ->
      List.fold_left Filename.concat home
        [ ".local"; "share"; "gamepilot"; name ]

let mgba_bridge_port = 47810

let defaults =
  {
    from_id = None;
    to_id = None;
    mode = None;
    runs = None;
    states = data_dir "GAMEPILOT_STATES" "states";
    runs_dir = data_dir "GAMEPILOT_RUNS" "runs";
    daemon = "daemon/build/gamepilot_daemon";
    mgba_port = mgba_bridge_port;
    backend = "mgba";
    serial = None;
    capture = None;
    replay = None;
    save_after_pass = true;
    preflight = false;
    make_room = None;
    max_rounds = None;
    common = { Checkpoint_command.defaults with port = 0 };
    watch = None;
    daemon_flags = [];
  }

let common_flag f c = { f with common = c f.common }

(* A flag with an int value: [set] applies it. *)
let int_flag name text set =
  match int_of_string_opt text with
  | Some n -> Ok (set n)
  | None -> Error ("bad " ^ name ^ " " ^ text)

let mode_flag f m =
  match Checkpoint_trials.mode_of_string m with
  | Some mode -> Ok { f with mode = Some mode }
  | None -> Error ("bad --mode " ^ m)

let keepawake_flag f seconds =
  {
    f with
    daemon_flags = f.daemon_flags @ [ "--keepawake"; string_of_int seconds ];
  }

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
  | "--port" ->
      Some
        (int_flag name v (fun port -> common_flag f (fun c -> { c with port })))
  | "--backend" -> Some (Ok { f with backend = v })
  | "--serial" -> Some (Ok { f with serial = Some v })
  | "--capture" -> Some (Ok { f with capture = Some v })
  | "--replay" -> Some (Ok { f with replay = Some v })
  | "--party" -> Some (Ok (common_flag f (fun c -> { c with party = v })))
  | "--grind-battles" -> (
      match int_of_string_opt v with
      | Some n when n > 0 ->
          Some (Ok (common_flag f (fun c -> { c with grind_cap = Some n })))
      | _ -> Some (Error ("bad --grind-battles " ^ v)))
  | "--make-room" -> Some (Ok { f with make_room = Some v })
  | "--max-rounds" -> (
      match int_of_string_opt v with
      | Some n when n > 0 -> Some (Ok { f with max_rounds = Some n })
      | _ -> Some (Error ("bad --max-rounds " ^ v)))
  | "--center" ->
      Some (Ok (common_flag f (fun c -> { c with center = Some v })))
  | "--keepawake" -> Some (int_flag name v (keepawake_flag f))
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

let valued f name v =
  match watch_valued f name v with Some r -> Some r | None -> valued f name v

let rec parse f = function
  | [] -> Ok f
  | "--watch" :: rest -> parse (watch_flag f Fun.id) rest
  | "--save-after-pass" :: rest -> parse { f with save_after_pass = true } rest
  | "--no-save-after-pass" :: rest ->
      parse { f with save_after_pass = false } rest
  | "--preflight" :: rest -> parse { f with preflight = true } rest
  | (("--record" | "--no-record") as flag) :: rest ->
      parse { f with daemon_flags = f.daemon_flags @ [ flag ] } rest
  | "--walk" :: rest ->
      parse (common_flag f (fun c -> { c with walk = true })) rest
  | "--end-check-only" :: rest ->
      parse (common_flag f (fun c -> { c with end_check_only = true })) rest
  | name :: v :: rest when Option.is_some (valued f name v) ->
      Result.bind (Option.get (valued f name v)) (fun f -> parse f rest)
  | a :: _ -> Error ("unknown argument " ^ a)

let required name = function
  | Some v -> Ok v
  | None -> Error (name ^ " is required")
