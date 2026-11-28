(* Shared manual console daemon session for [gamepilot console watch|park|resume]
   and [gamepilot ctl --console ID]: starts a daemon for a configured console
   using its configured [watch_port] and registers it in the watch hub registry
   ([--registry <runs_dir>/.watch]) so manual sessions appear on the watch page
   and hub with zero extra flags. *)

let ( let* ) = Result.bind

type options = {
  daemon : string;
  runs_dir : string;
  log_dir : string;
  config : string option;
  port : int;
  watch_port : int option;
  listen : string option;
}

let defaults ?(port = 0) () =
  {
    daemon = Repo_io.Repo_files.default_daemon ();
    runs_dir = Attached_run.default_runs_dir ();
    log_dir = Filename.get_temp_dir_name ();
    config = None;
    port;
    watch_port = None;
    listen = None;
  }

let backend_of_console (c : Console_config.console) =
  match c.backend with
  | Switch { serial; capture } ->
      Daemon_process.Switch { serial; frames = Daemon_process.Capture capture }
  | Mgba { port } -> Daemon_process.Mgba { port }

let watch_for_console (o : options) (c : Console_config.console) =
  let watch : Daemon_process.watch =
    {
      listen = Option.value o.listen ~default:(Watch_urls.default_listen ());
      port = Console_config.effective_watch_port ~explicit:o.watch_port c;
      token = Watch_urls.new_token ();
      registry = Filename.concat o.runs_dir ".watch";
    }
  in
  Watch_hub.for_runs_dir ~daemon:o.daemon ~runs_dir:o.runs_dir (Some watch)

let announce (c : Console_config.console) watch (d : Daemon_process.t) =
  Printf.printf "[Console] %s (%s): daemon rpc port %d\n%!" c.id c.name d.port;
  match (watch, d.watch_port) with
  | Some (w : Daemon_process.watch), Some port ->
      Watch_urls.print ~listen:w.listen ~token:w.token ~port
  | _ -> ()

let start_for_console (o : options) ~checkpoint (c : Console_config.console) =
  let watch = watch_for_console o c in
  let file ext = Filename.concat o.log_dir ("gamepilot-" ^ checkpoint ^ ext) in
  let* d =
    Daemon_process.start ?watch ~daemon:o.daemon ~backend:(backend_of_console c)
      ~port:o.port ~wire_log:(file ".wire.jsonl") ~out_file:(file ".daemon.out")
      ~checkpoint ()
  in
  announce c watch d;
  Ok d

let with_console (o : options) ~console_id ~checkpoint body =
  let* c = Console_config.resolve ?path:o.config console_id in
  let* d = start_for_console o ~checkpoint c in
  Ok (Fun.protect ~finally:(fun () -> Daemon_process.stop d) (fun () -> body d))

let watch_console (o : options) ~console_id =
  let* c = Console_config.resolve ?path:o.config console_id in
  let* d = start_for_console o ~checkpoint:("manual-" ^ c.id) c in
  Printf.printf "[Console] control with: gamepilot ctl%s COMMAND\n%!"
    (if d.port = Live.default_port then ""
     else Printf.sprintf " --port %d" d.port);
  Daemon_process.wait d;
  Ok 0
