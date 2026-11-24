(* The hub (gamepilot_daemon --hub, docs/design/Watch-Page.md): the page at
   127.0.0.1:47901 listing the live runs from the watch registry. The runner
   starts it when nothing answers on its port; it runs in its own session, so
   it outlives the run, and one already running makes this a no-op. *)

let connect_timeout_s = 0.5

(* Whether something accepts connections on the hub's port. *)
let running () =
  let socket = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close socket)
    (fun () ->
      Unix.setsockopt_float socket Unix.SO_SNDTIMEO connect_timeout_s;
      match
        Unix.connect socket
          (Unix.ADDR_INET (Unix.inet_addr_loopback, Watch_urls.hub_port))
      with
      | () -> true
      | exception Unix.Unix_error _ -> false)

let hub_args ~daemon (watch : Daemon_process.watch) =
  [|
    daemon;
    "--hub";
    "--registry";
    watch.registry;
    "--listen";
    watch.listen;
    "--watch-port";
    string_of_int Watch_urls.hub_port;
  |]

let spawn ~daemon (watch : Daemon_process.watch) out =
  match
    Unix.create_process daemon (hub_args ~daemon watch) Unix.stdin out out
  with
  | (_ : int) -> print_endline "[Watch] started the hub"
  | exception Unix.Unix_error (e, _, _) ->
      print_endline ("[Watch] could not start the hub: " ^ Unix.error_message e)

(* Starts the hub unless one runs; its output goes to hub.out in the
   registry. *)
let ensure ~daemon (watch : Daemon_process.watch) =
  if not (running ()) then (
    Run_record.make_dirs watch.registry;
    let out =
      Unix.openfile
        (Filename.concat watch.registry "hub.out")
        [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_APPEND ]
        0o644
    in
    spawn ~daemon watch out;
    Unix.close out)
