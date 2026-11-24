(* gamepilot checkpoints PLAN_DIR --from ID --to ID --mode testing|verification
     [--runs N] [--states DIR] [--runs-dir DIR] [--daemon PATH]
     [--mgba-port N] [--port N] [--party SPECIES,...] [--center TOWN] [--walk]
     [--end-check-only] [--grind-battles N] [--watch] [--watch-port N]
     [--listen ADDR] [--backend mgba|switch --serial PORT --capture DEVICE]

   The checkpoint dev loop. A program's checkpoints are its plan files
   (<ID>.plan.json in PLAN_DIR, in name order); each runs from its start state
   (<states>/<ID>.start.ss), as many times as the mode's policy says
   (Story.Checkpoint_trials), each run with its own daemon and run folder
   (Run_record). A run passes when every event passed and the player ends at
   the checkpoint's declared end (Story.Checkpoint_end) and the plan's
   postconditions hold (Story.Postcondition_check). With --end-check-only each
   run checks its start state against the postconditions and runs no event. The loop goes to the
   next checkpoint only after this one passed; in verification mode the last
   passing run's end becomes the next checkpoint's start state.

   --grind-battles N (testing) ends each grind, passing, after N battles: the
   run's summary says "grind capped at N" and which postconditions it skipped,
   and its end is never saved as the next checkpoint's start.

   --watch serves the run's watch page (the daemon's, docs/design/Watch-Page.md)
   on a free port (--watch-port fixes it), the same for every run of the
   series, lists it in the watch registry ($GAMEPILOT_RUNS/.watch) and starts
   the hub (Watch_hub, 127.0.0.1:47901) if none runs. --listen 0.0.0.0 (or
   $GAMEPILOT_WATCH_LISTEN) opens both to the LAN; Stop then takes the series'
   token, which the URL printed for other devices carries. The program's port
   (--port) is a free one too unless given, so runs do not collide.

   --backend switch runs on the Switch (docs/switch-bring-up.md): the daemon
   drives the controller board on --serial and reads the capture card
   --capture (gamepilot switch-devices prints the lab's). The console holds
   the start, the save the user loaded, so there are no start states and
   only --mode testing runs.

   --states defaults to $GAMEPILOT_STATES and --runs-dir to $GAMEPILOT_RUNS,
   else to $HOME/.local/share/gamepilot/{states,runs}.

   Mirrors, on the fork's frlg/lean (SerialPrograms/Source/Pokemon/AutoStory/):
   the START/END_CHECKPOINT range (Options/Pokemon_StoryRangeOptions.h) and
   StoryEngine::run_checkpoints() (Engine/Pokemon_StoryEngine.cpp) over it;
   verify_checkpoint() (Engine/Pokemon_StoryVerifyRuns.cpp) for the runs of
   one checkpoint; the program leaving the game where it failed
   (STORY_LEFT_WHERE_FAILED in PokemonFRLG_AutoStory.cpp), here as failure.ss.
   Not ported yet: retries inside a run (StoryGame::attempts_per_checkpoint
   with reload), the reproduction phase, the overlay log. mGBA itself is
   started and closed around the command by tools/run_checkpoints_on_mgba.sh. *)

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
  common : Checkpoint_command.flags;
  watch : Daemon_process.watch option;
}

let usage =
  "  gamepilot checkpoints PLAN_DIR --from ID --to ID --mode \
   testing|verification\n\
  \      [--runs N] [--states DIR] [--runs-dir DIR] [--daemon PATH]\n\
  \      [--mgba-port N] [--port N] [--party SPECIES,...] [--center TOWN] \
   [--walk]\n\
  \      [--end-check-only] [--grind-battles N] [--watch] [--watch-port N]\n\
  \      [--listen ADDR] [--backend mgba|switch --serial PORT --capture DEVICE]\n"

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
    common = { Checkpoint_command.defaults with port = 0 };
    watch = None;
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
  | "--party" -> Some (Ok (common_flag f (fun c -> { c with party = v })))
  | "--grind-battles" -> (
      match int_of_string_opt v with
      | Some n when n > 0 ->
          Some (Ok (common_flag f (fun c -> { c with grind_cap = Some n })))
      | _ -> Some (Error ("bad --grind-battles " ^ v)))
  | "--center" ->
      Some (Ok (common_flag f (fun c -> { c with center = Some v })))
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
  | "--walk" :: rest ->
      parse (common_flag f (fun c -> { c with walk = true })) rest
  | "--end-check-only" :: rest ->
      parse (common_flag f (fun c -> { c with end_check_only = true })) rest
  | name :: v :: rest when Option.is_some (valued f name v) ->
      Result.bind (Option.get (valued f name v)) (fun f -> parse f rest)
  | a :: _ -> Error ("unknown argument " ^ a)

let plan_suffix = ".plan.json"

(* Checkpoint ids in the folder, in run order ({!Story.Checkpoint_order}). *)
let checkpoint_ids dir =
  match Sys.readdir dir with
  | names ->
      Ok
        (Array.to_list names
        |> List.filter (fun n -> Filename.check_suffix n plan_suffix)
        |> List.map (fun n -> Filename.chop_suffix n plan_suffix)
        |> List.sort Story.Checkpoint_order.compare)
  | exception Sys_error e -> Error e

let rec drop_until id = function
  | [] -> []
  | x :: rest as all -> if x = id then all else drop_until id rest

(* [from_id .. to_id] and the id after [to_id], if any. *)
let select ids ~from_id ~to_id =
  let from = drop_until from_id ids in
  match (from, drop_until to_id from) with
  | [], _ -> Error ("no checkpoint " ^ from_id)
  | _, [] -> Error ("no checkpoint " ^ to_id ^ " at or after " ^ from_id)
  | _, _ :: after ->
      let n = List.length from - List.length after in
      Ok (List.filteri (fun i _ -> i < n) from, List.nth_opt after 0)

let required name = function
  | Some v -> Ok v
  | None -> Error (name ^ " is required")

let ( let* ) = Result.bind

(* The daemon's backend from the flags; the Switch only in testing mode. *)
let daemon_backend f mode =
  match (f.backend, f.serial, f.capture, mode) with
  | "mgba", None, None, _ -> Ok (Daemon_process.Mgba { port = f.mgba_port })
  | "mgba", _, _, _ -> Error "--serial and --capture need --backend switch"
  | "switch", Some serial, Some capture, Checkpoint_trials.Testing ->
      Ok (Daemon_process.Switch { serial; capture })
  | "switch", Some _, Some _, Verification ->
      Error "--backend switch runs only --mode testing"
  | "switch", _, _, _ -> Error "--backend switch needs --serial and --capture"
  | b, _, _, _ -> Error ("bad --backend " ^ b)

let main plan_dir args =
  let* f = parse defaults args in
  let* from_id = required "--from" f.from_id in
  let* to_id = required "--to" f.to_id in
  let* mode = required "--mode" f.mode in
  let* backend = daemon_backend f mode in
  let* policy = Checkpoint_trials.policy ?runs:f.runs mode in
  let* ids = checkpoint_ids plan_dir in
  let* selected, after = select ids ~from_id ~to_id in
  let* world = Frlg_story.Checkpoint_run.load_world () in
  (* --runs-dir may come after --watch. *)
  let watch =
    Option.map
      (fun w ->
        { w with Daemon_process.registry = Filename.concat f.runs_dir ".watch" })
      f.watch
  in
  Option.iter (Watch_hub.ensure ~daemon:f.daemon) watch;
  Ok
    (Checkpoint_series.run ~plan_dir
       {
         states = f.states;
         runs_dir = f.runs_dir;
         daemon = f.daemon;
         backend;
         common = f.common;
         mode;
         policy;
         world;
         watch;
         bound = ref None;
       }
       selected ~after)
