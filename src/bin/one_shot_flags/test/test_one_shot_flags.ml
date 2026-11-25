(* One_shot_flags: a one-shot program on a daemon already up, or in its own
   with --watch, and the flags it refuses. *)

module D = Live_run.Daemon_process

let program = Option.get (Program_registry.find "frlg.start_menu_poc")

let backend = function
  | D.Mgba { port } -> Printf.sprintf "mgba:%d" port
  | Switch { serial; _ } ->
      "switch:" ^ Option.value serial ~default:"fake board"

let daemon = function
  | One_shot_flags.Attach port -> Printf.sprintf "attach %d" port
  | Start own ->
      Printf.sprintf "start %s port %d page %d %s [%s]" (backend own.backend)
        own.port own.watch.port own.watch.listen
        (String.concat " " own.daemon_flags)

let show = function
  | Ok (t : One_shot_flags.t) ->
      Printf.sprintf "%s, state %s" (daemon t.daemon)
        (Option.value t.state ~default:"none")
  | Error e -> "error: " ^ e

let run args () =
  show (One_shot_flags.parse program ~default_state:"overworld.ss" args)

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Unix.putenv "GAMEPILOT_WATCH_LISTEN" "127.0.0.1";
  Table_test.run "one_shot_flags"
    [
      case "no flags: the daemon on 47900, the program's state" (run [])
        "attach 47900, state overworld.ss";
      case "--port, --console"
        (run [ "--port"; "47950"; "--console" ])
        "attach 47950, state none";
      case "--state" (run [ "--state"; "a.ss" ]) "attach 47900, state a.ss";
      case "--watch: its own daemon on mGBA, any free ports" (run [ "--watch" ])
        "start mgba:47810 port 0 page 0 127.0.0.1 [], state overworld.ss";
      case "--listen and --mgba-port"
        (run [ "--listen"; "0.0.0.0"; "--mgba-port"; "47811"; "--console" ])
        "start mgba:47811 port 0 page 0 0.0.0.0 [], state none";
      case "--watch-port, --port and --speed"
        (run
           [
             "--watch-port";
             "47999";
             "--port";
             "47998";
             "--speed";
             "4";
             "--watch";
           ])
        "start mgba:47810 port 47998 page 47999 127.0.0.1 [--speed 4], state \
         overworld.ss";
      case "the Switch dry run loads no state"
        (run [ "--watch"; "--backend"; "switch"; "--replay"; "v.mp4" ])
        "start switch:fake board port 0 page 0 127.0.0.1 [--viewport nso-gba], \
         state none";
      case "a daemon's flag without --watch"
        (run [ "--mgba-port"; "47811" ])
        "error: flags of the program's own daemon, which needs --watch: \
         --mgba-port";
      case "a series' flags"
        (run [ "--watch"; "--from"; "a"; "--mode"; "testing" ])
        "error: a checkpoint series' flags, not a one-shot program's: --from, \
         --mode";
      case "an unknown flag"
        (run [ "--party"; "MEW" ])
        "error: unknown argument --party";
    ]
