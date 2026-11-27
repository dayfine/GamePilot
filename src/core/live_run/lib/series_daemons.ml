(* The daemons of a checkpoint series, one per run, each asking for the ports
   the one before it bound, and the series they serve, told to the watch page
   (Series_watch). The daemons' start and ports are moved unchanged from FRLG's
   Checkpoint_live_run. *)

type series = {
  info : Run_record.info;
  mode : string;
  checkpoints : string list;
}

type t = {
  series : series;
  watched : Series_watch.t; (* The series on the watch page as one run. *)
  daemon : string;
  backend : Daemon_process.backend;
  flags : string list;
  port : int;
  watch : Daemon_process.watch option;
  bound : (int * int option) option ref;
      (* The ports the last daemon bound (program, page). *)
}

let create ~daemon ~backend ~flags ~port ~watch series =
  let watched =
    Series_watch.start watch series.info ~mode:series.mode series.checkpoints
  in
  { series; watched; daemon; backend; flags; port; watch; bound = ref None }

let series t = t.series

let start t record ~checkpoint (port, watch) =
  Daemon_process.start ?watch ~flags:t.flags ~daemon:t.daemon ~backend:t.backend
    ~port
    ~wire_log:(Run_record.path record "wire.jsonl")
    ~out_file:(Run_record.path record "daemon.out")
    ~checkpoint ()

(* The ports the last daemon bound, else the asked ones (0: any); the asked
   ones when those are taken now. *)
let start_sticky t record ~checkpoint =
  let asked = (t.port, t.watch) in
  let again =
    match !(t.bound) with
    | None -> asked
    | Some (port, page) ->
        let keep (w : Daemon_process.watch) =
          { w with port = Option.value page ~default:w.port }
        in
        (port, Option.map keep t.watch)
  in
  match start t record ~checkpoint again with
  | Error _ when again <> asked -> start t record ~checkpoint asked
  | started -> started

(* Prints the page's URLs when they are new: at the first run, or when the
   last run's ports were taken. *)
let announce t (daemon : Daemon_process.t) =
  let bound = Some (daemon.port, daemon.watch_port) in
  (match (t.watch, daemon.watch_port) with
  | Some w, Some port when !(t.bound) <> bound ->
      Watch_urls.print ~listen:w.listen ~token:w.token ~port
  | _ -> ());
  t.bound := bound

let with_daemon t ~failed (run : Run_record.run) ~n body =
  Series_watch.run_started t.watched run ~n;
  Daemon_run.with_daemon ~failed
    (start_sticky t run.record ~checkpoint:run.checkpoint) (fun daemon ->
      announce t daemon;
      body daemon)

let finish t ~runs_dir run ~summary ending =
  Daemon_run.finish ~runs_dir run ~summary ending;
  Series_watch.run_ended t.watched run ending

let finished t ~passed = Series_watch.finished t.watched ~passed

type close_game_action = Close_game | Skip_failed_run | No_close

let close_game_action ~close_game ~backend ~passed =
  match (close_game, backend, passed) with
  | true, Daemon_process.Switch _, true -> Close_game
  | true, Daemon_process.Switch _, false -> Skip_failed_run
  | false, _, _ | true, Daemon_process.Mgba _, _ -> No_close

let run_ephemeral_session t ~checkpoint body =
  let log_dir = Filename.get_temp_dir_name () in
  let file ext = Filename.concat log_dir ("gamepilot-" ^ checkpoint ^ ext) in
  let failed ({ reason; _ } : Daemon_run.failed) = Error reason in
  let started =
    Daemon_process.start
      ~flags:(t.flags @ [ "--no-record" ])
      ~daemon:t.daemon ~backend:t.backend ~port:0 ~wire_log:(file ".wire.jsonl")
      ~out_file:(file ".daemon.out") ~checkpoint ()
  in
  Daemon_run.with_daemon ~failed started (fun daemon ->
      Daemon_run.in_session ~failed ~dir:log_dir (fun () ->
          Live.run_with_backend ~port:daemon.port body))

let close_game_now t ?tile () =
  let step (b : Wire.backend) =
    Switch.Console_park.park_and_close ~log:print_endline ~picture:b.viewport
      ?tile ()
  in
  match run_ephemeral_session t ~checkpoint:"close-game" step with
  | Ok () ->
      print_endline "[Close game] done";
      true
  | Error e ->
      print_endline ("[Close game] failed: " ^ e);
      false

let close_game_after_pass t ~close_game ?tile ~passed () =
  match close_game_action ~close_game ~backend:t.backend ~passed with
  | Close_game -> close_game_now t ?tile ()
  | Skip_failed_run ->
      print_endline
        "[Close game] skipped (run did not pass; keeping console state)";
      true
  | No_close -> true
