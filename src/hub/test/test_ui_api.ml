(* Ui_api, External_runs, and Http_router: pure JSON encoding, argv
   construction, ps parsing, and HTTP route contract tests (no sockets). *)

open Ui_hub

let case name input expectation : Table_test.case = { name; input; expectation }

let sample_console : Console_config.console =
  {
    id = "console-a";
    name = "Console A";
    backend = Switch { serial = Some "/dev/cu.usbserial-1"; capture = "0" };
  }

let build_run json () =
  match Ui_api.decode_launch (Yojson.Safe.from_string json) with
  | Error e -> "decode error: " ^ e
  | Ok req -> (
      match
        Ui_api.build_run_argv ~gamepilot:"gamepilot" ~console:sample_console req
      with
      | Ok argv -> String.concat " " argv
      | Error e -> "build error: " ^ e)

let programs_has_supplies () =
  match Ui_api.programs_json () with
  | `Assoc [ ("programs", `List items) ] ->
      let has =
        List.exists
          (function
            | `Assoc fields ->
                List.assoc_opt "id" fields = Some (`String "frlg.supplies")
            | _ -> false)
          items
      in
      string_of_bool has
  | _ -> "bad shape"

let with_temp_router f =
  let dir = Filename.temp_file "ui_hub_test_" "" in
  Sys.remove dir;
  let path = Filename.concat dir "consoles.json" in
  let mgr = Run_manager.create ~config_path:path ~runs_dir:dir () in
  let res = f mgr in
  if Sys.file_exists path then Sys.remove path;
  if Sys.file_exists dir then Sys.rmdir dir;
  res

let router_console_roundtrip () =
  with_temp_router (fun mgr ->
      let c1, _, _ = Http_router.route mgr "GET" "/" "" in
      let c2, _, _ =
        Http_router.route mgr "POST" "/api/consoles"
          {|{"id":"mgba","name":"Local mGBA","backend":"mgba","mgba_port":47810}|}
      in
      let c3, _, body = Http_router.route mgr "GET" "/api/consoles" "" in
      let has_mgba =
        match Yojson.Safe.from_string body with
        | `Assoc fs -> (
            match List.assoc_opt "consoles" fs with
            | Some (`List [ _ ]) -> true
            | _ -> false)
        | _ -> false
      in
      Printf.sprintf "%d:%d:%d:%b" c1 c2 c3 has_mgba)

let router_error_codes () =
  with_temp_router (fun mgr ->
      let c_bad_json, _, _ =
        Http_router.route mgr "POST" "/api/consoles" "{bad"
      in
      let c_missing_console, _, _ =
        Http_router.route mgr "POST" "/api/runs"
          {|{"console":"nope","program":"frlg.supplies"}|}
      in
      let c_missing_stop, _, _ =
        Http_router.route mgr "POST" "/api/runs/run-99/stop" ""
      in
      let c_404, _, _ = Http_router.route mgr "GET" "/no-such-route" "" in
      Printf.sprintf "%d:%d:%d:%d" c_bad_json c_missing_console c_missing_stop
        c_404)

let () =
  Table_test.run "ui_api"
    [
      case "programs_json includes frlg.supplies" programs_has_supplies "true";
      case "build_run_argv default mode uses --mode testing for checkpoints"
        (build_run
           {|{"console":"console-a","program":"frlg.supplies","from":"su-01","to":"su-01","mode":"default","options":{"retro-mail":"20","super-repel":"0"}}|})
        "gamepilot run frlg.supplies --backend switch --capture 0 --serial \
         /dev/cu.usbserial-1 --from su-01 --to su-01 --mode testing --watch \
         --options retro-mail=20 --options super-repel=0";
      case "build_run_argv explicit verification mode passes --mode"
        (build_run
           {|{"console":"console-a","program":"frlg.supplies","from":"su-01","to":"su-01","mode":"verification","options":{"retro-mail":"20","super-repel":"0"}}|})
        "gamepilot run frlg.supplies --backend switch --capture 0 --serial \
         /dev/cu.usbserial-1 --from su-01 --to su-01 --mode verification \
         --watch --options retro-mail=20 --options super-repel=0";
      case "build_run_argv for preflight omits --watch"
        (build_run
           {|{"console":"console-a","program":"frlg.supplies","from":"su-01","preflight":true}|})
        "gamepilot run frlg.supplies --backend switch --capture 0 --serial \
         /dev/cu.usbserial-1 --preflight --from su-01 --options retro-mail=100 \
         --options super-repel=5";
      case "build_run_argv rejects invalid option value"
        (build_run
           {|{"console":"console-a","program":"frlg.supplies","options":{"retro-mail":"9999"}}|})
        "build error: --options retro-mail=9999: retro-mail is 0 to 999";
      case "external_runs parses daemon line and skips hub"
        (fun () ->
          let lines =
            [
              "56269 /path/gamepilot_daemon --hub --watch-port 47901";
              "80610 /path/gamepilot_daemon --backend switch --serial \
               /dev/cu.usbserial-1 --checkpoint bdsp.underground --registry \
               /tmp/watch";
            ]
          in
          let runs = External_runs.parse_ps_lines lines in
          match External_runs.match_console runs sample_console with
          | Some r ->
              Printf.sprintf "%d:%s:%s" r.pid r.program
                (Option.value r.registry ~default:"")
          | None -> "none")
        "80610:bdsp.underground:/tmp/watch";
      case "http_router serves page and console upsert roundtrip"
        router_console_roundtrip "200:200:200:true";
      case "http_router returns expected 400/404 status codes"
        router_error_codes "400:404:404:404";
      case "run_history parses RESULTS.tsv newest-first with limit"
        (fun () ->
          let tsv =
            "time\trun\tcheckpoint\tmode\tresult\tat\treason\n\
             2026-11-26T01:00:00\trun-1\tsu-01\ttesting\tpass\t\t\n\
             2026-11-26T02:00:00\trun-2\tbdsp.underground\trun\tfail\t#1\tbad \
             fade\n"
          in
          let entries = Run_history.parse_tsv ~limit:1 tsv in
          match entries with
          | [ e ] ->
              Printf.sprintf "%s:%s:%s:%s" e.run e.checkpoint e.result e.reason
          | _ -> "bad count")
        "run-2:bdsp.underground:fail:bad fade";
    ]
