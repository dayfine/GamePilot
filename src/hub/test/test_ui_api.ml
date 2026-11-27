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
      let c_css, _, _ = Http_router.route mgr "GET" "/style.css" "" in
      let c_js, _, _ = Http_router.route mgr "GET" "/app.js" "" in
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
      Printf.sprintf "%d:%d:%d:%d:%d:%b" c1 c_css c_js c2 c3 has_mgba)

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

let write_file path content =
  Out_channel.with_open_text path (fun oc -> output_string oc content)

let rec rm_rf path =
  if Sys.file_exists path then
    if Sys.is_directory path then (
      Array.iter
        (fun name -> rm_rf (Filename.concat path name))
        (Sys.readdir path);
      Sys.rmdir path)
    else Sys.remove path

let run_history_merge_test () =
  let dir = Filename.temp_file "ui_hub_hist_" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  let r1 = Filename.concat dir "2026-11-26-su-01-testing-1" in
  let r2 = Filename.concat dir "2026-11-26-02.99-unknown-testing-1" in
  Unix.mkdir r1 0o755;
  Unix.mkdir (Filename.concat r1 "frames") 0o755;
  Unix.mkdir r2 0o755;
  write_file
    (Filename.concat dir "RESULTS.tsv")
    "time\trun\tcheckpoint\tmode\tresult\tat\treason\n\
     2026-11-26T10:00:00\t2026-11-26-su-01-testing-1\tsu-01\ttesting\tpass\t\t\n\
     2026-11-26T11:00:00\t2026-11-26-02.99-unknown-testing-1\t02.99-unknown\ttesting\tfail\t#2\tbad \
     fade\n";
  write_file
    (Filename.concat r1 "run.json")
    {|{"game":"frlg","game_name":"Pokemon FireRed / LeafGreen","program":"frlg.supplies","program_name":"Supplies","group":"Farming","from":"su-01","to":"su-02","checkpoint":"su-01","backend":"switch","mode":"testing","result":"pass","started_ms":1700000000000,"ended_ms":1700000060000}|};
  write_file (Filename.concat (Filename.concat r1 "frames") "index.jsonl") "";
  write_file
    (Filename.concat r2 "daemon.json")
    {|{"backend":"mgba","clock_zero_unix_ms":1700000100000}|};
  let entries = Run_history.load ~runs_dir:dir () in
  let json = Run_history.to_json ~runs_dir:dir entries in
  let port =
    match json with
    | `Assoc fs -> (
        match List.assoc_opt "watch_hub_port" fs with
        | Some (`Int p) -> p
        | _ -> 0)
    | _ -> 0
  in
  rm_rf dir;
  let summary =
    List.map
      (fun (e : Run_history.entry) ->
        Printf.sprintf "%s:%s:%s:%s:%s:%s:%b" e.run e.game e.program e.from
          e.to_ e.backend e.recorded)
      entries
  in
  Printf.sprintf "port=%d | %s" port (String.concat " | " summary)

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
      case "http_router serves HTML/CSS/JS and console upsert roundtrip"
        router_console_roundtrip "200:200:200:200:200:true";
      case "http_router returns expected 400/404 status codes"
        router_error_codes "400:404:404:404";
      case
        "run_history parses RESULTS.tsv newest-first and ignores numeric \
         prefixes"
        (fun () ->
          let tsv =
            "time\trun\tcheckpoint\tmode\tresult\tat\treason\n\
             2026-11-26T01:00:00\trun-1\t01.02-platform-to-plaza\ttesting\tpass\t\t\n\
             2026-11-26T02:00:00\trun-2\tbdsp.underground\trun\tfail\t#1\tbad \
             fade\n"
          in
          let entries = Run_history.parse_tsv ~limit:2 tsv in
          String.concat " | "
            (List.map
               (fun (e : Run_history.entry) ->
                 Printf.sprintf "%s:%s:%s" e.game e.checkpoint e.result)
               entries))
        "bdsp:bdsp.underground:fail | plza:01.02-platform-to-plaza:pass";
      case "run_history merges run.json, daemon.json, frames, and RESULTS.tsv"
        run_history_merge_test
        "port=47901 | \
         2026-11-26-02.99-unknown-testing-1:::02.99-unknown:02.99-unknown:mgba:false \
         | \
         2026-11-26-su-01-testing-1:frlg:frlg.supplies:su-01:su-02:switch:true";
    ]
