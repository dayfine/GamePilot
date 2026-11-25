(* The daemons of a checkpoint series, one per run, each asking for the ports
   the one before it bound, and the series they serve. The daemons' start and
   ports are moved unchanged from FRLG's Checkpoint_live_run. *)

type series = {
  info : Run_record.info;
  mode : string;
  checkpoints : string list;
}

type t = {
  series : series;
  daemon : string;
  backend : Daemon_process.backend;
  flags : string list;
  port : int;
  watch : Daemon_process.watch option;
  bound : (int * int option) option ref;
      (* The ports the last daemon bound (program, page). *)
}

let create ~daemon ~backend ~flags ~port ~watch series =
  { series; daemon; backend; flags; port; watch; bound = ref None }

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

let with_daemon t ~failed (run : Run_record.run) ~n:_ body =
  Daemon_run.with_daemon ~failed
    (start_sticky t run.record ~checkpoint:run.checkpoint) (fun daemon ->
      announce t daemon;
      body daemon)

let finish _ ~runs_dir run ~summary ending =
  Daemon_run.finish ~runs_dir run ~summary ending

let finished _ ~passed:_ = ()
