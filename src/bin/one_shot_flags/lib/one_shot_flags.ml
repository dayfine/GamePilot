(* gamepilot run <one-shot program>'s flags (One_shot_flags.mli). With
   --watch the run's daemon is a checkpoint run's (Daemon_process, Watch_hub,
   Watch_urls), stopped after the run by its caller (Daemon_run.with_daemon). *)

module F = Checkpoints_flags

(* The program's own flags: the save state to load, none for --console. *)
let game_flags default_state : string option F.game_flags =
  {
    game_defaults = Some default_state;
    game_switch = (fun _ name -> if name = "--console" then Some None else None);
    game_valued =
      (fun _ name v -> if name = "--state" then Some (Ok (Some v)) else None);
  }

type own = {
  build : string;
  backend : Daemon_process.backend;
  backend_name : string;
  daemon_flags : string list;
  port : int;
  watch : Daemon_process.watch;
}

type daemon = Attach of int | Start of own
type t = { runs_dir : string; state : string option; daemon : daemon }

(* The flags given that only a checkpoint series reads. *)
let series_flags (d : _ F.flags) (f : _ F.flags) =
  [
    ("--from", f.from_id <> d.from_id);
    ("--to", f.to_id <> d.to_id);
    ("--mode", f.mode <> d.mode);
    ("--runs", f.runs <> d.runs);
    ("--states", f.states <> d.states);
    ("--preflight", f.preflight <> d.preflight);
    ("--no-save-after-pass", f.save_after_pass <> d.save_after_pass);
    ("--max-rounds", f.max_rounds <> d.max_rounds);
    ("--from-event", f.from_event <> d.from_event);
    ("--to-event", f.to_event <> d.to_event);
  ]

(* The flags given that start a daemon of the program's own. *)
let daemon_flags (d : _ F.flags) (f : _ F.flags) =
  [
    ("--daemon", f.daemon <> d.daemon);
    ("--mgba-port", f.mgba_port <> d.mgba_port);
    ("--backend", f.backend <> d.backend);
    ("--serial", f.serial <> d.serial);
    ("--capture", f.capture <> d.capture);
    ("--replay", f.replay <> d.replay);
    ("--viewport", f.viewport <> d.viewport);
    ("--record, --no-record, --keepawake, --speed", f.daemon_flags <> []);
  ]

let given flags =
  List.filter_map (fun (n, g) -> if g then Some n else None) flags

let refuse why = function
  | [] -> Ok ()
  | names -> Error (why ^ ": " ^ String.concat ", " names)

let ( let* ) = Result.bind

(* The program's own daemon, from the flags: a checkpoint run's backend
   (testing: a one-shot has no verification) and the program's viewport. *)
let own (p : Program_registry.t) (f : _ F.flags) watch =
  let* backend = F.daemon_backend f Engine_run.Checkpoint_trials.Testing in
  let* viewport = Program_registry.check_viewport (Some p) f.viewport in
  Ok
    {
      build = f.daemon;
      backend;
      backend_name = f.backend;
      daemon_flags =
        Daemon_process.viewport_args backend viewport @ f.daemon_flags;
      port = f.port;
      watch;
    }

let parse (p : Program_registry.t) ~default_state args =
  let game = game_flags default_state in
  let d = F.defaults game in
  let* f = F.parse game d args in
  let* () =
    refuse "a checkpoint series' flags, not a one-shot program's"
      (given (series_flags d f))
  in
  match f.watch with
  | None ->
      let* () =
        refuse "flags of the program's own daemon, which needs --watch"
          (given (daemon_flags d f))
      in
      let port = if f.port = d.port then Live.default_port else f.port in
      Ok { runs_dir = f.runs_dir; state = f.game; daemon = Attach port }
  | Some watch ->
      let* own = own p f watch in
      (* The Switch keeps no save states: its game is the start. *)
      let state =
        match own.backend with Switch _ -> None | Mgba _ -> f.game
      in
      Ok { runs_dir = f.runs_dir; state; daemon = Start own }

(* The page, listed in the registry beside [runs_dir], with the hub started
   if none runs. *)
let with_hub own ~runs_dir =
  match Watch_hub.for_runs_dir ~daemon:own.build ~runs_dir (Some own.watch) with
  | Some watch -> watch
  | None -> own.watch

let start own ~runs_dir (record : Run_record.t) ~label =
  let watch = with_hub own ~runs_dir in
  let started =
    Daemon_process.start ~watch ~flags:own.daemon_flags ~daemon:own.build
      ~backend:own.backend ~port:own.port
      ~wire_log:(Run_record.path record "wire.jsonl")
      ~out_file:(Run_record.path record "daemon.out")
      ~checkpoint:label ()
  in
  Result.iter
    (fun (d : Daemon_process.t) ->
      Option.iter
        (fun port ->
          Watch_urls.print ~listen:watch.listen ~token:watch.token ~port)
        d.watch_port)
    started;
  started
