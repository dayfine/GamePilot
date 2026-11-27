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

let check_eq ~fmt name ~expected ~actual =
  Table_test.report name
    (if actual = expected then Ok ()
     else
       Error (Printf.sprintf "expected %s, got %s" (fmt expected) (fmt actual)))

let check_str = check_eq ~fmt:(Printf.sprintf "%S")
let check_bool = check_eq ~fmt:string_of_bool

let check_parse_tsv () =
  let tsv =
    "time\trun\tcheckpoint\tmode\tresult\tat\treason\n\
     2026-11-26T01:00:00\trun-1\t01.02-platform-to-plaza\ttesting\tpass\t\t\n\
     2026-11-26T02:00:00\trun-2\tbdsp.underground\trun\tfail\t#1\tbad fade\n"
  in
  match Run_history.parse_tsv ~limit:2 tsv with
  | [ first; second ] ->
      check_str "run_history parse_tsv newest game" ~expected:"bdsp"
        ~actual:first.game;
      check_str "run_history parse_tsv newest checkpoint"
        ~expected:"bdsp.underground" ~actual:first.checkpoint;
      check_str "run_history parse_tsv newest result" ~expected:"fail"
        ~actual:first.result;
      check_str "run_history parse_tsv older game" ~expected:"plza"
        ~actual:second.game;
      check_str "run_history parse_tsv older checkpoint"
        ~expected:"01.02-platform-to-plaza" ~actual:second.checkpoint;
      check_str "run_history parse_tsv older result" ~expected:"pass"
        ~actual:second.result
  | entries ->
      Table_test.report "run_history parse_tsv returns two entries"
        (Error
           (Printf.sprintf "expected 2 entries, got %d" (List.length entries)))

let check_merged_daemon_entry (e : Run_history.entry) =
  check_str "run_history merge daemon-only run id"
    ~expected:"2026-11-26-02.99-unknown-testing-1" ~actual:e.run;
  check_str "run_history merge daemon-only game" ~expected:"" ~actual:e.game;
  check_str "run_history merge daemon-only program" ~expected:""
    ~actual:e.program;
  check_str "run_history merge daemon-only from" ~expected:"02.99-unknown"
    ~actual:e.from;
  check_str "run_history merge daemon-only to" ~expected:"02.99-unknown"
    ~actual:e.to_;
  check_str "run_history merge daemon-only backend" ~expected:"mgba"
    ~actual:e.backend;
  check_bool "run_history merge daemon-only recorded" ~expected:false
    ~actual:e.recorded

let check_merged_full_entry (e : Run_history.entry) =
  check_str "run_history merge full run id"
    ~expected:"2026-11-26-su-01-testing-1" ~actual:e.run;
  check_str "run_history merge full game" ~expected:"frlg" ~actual:e.game;
  check_str "run_history merge full program" ~expected:"frlg.supplies"
    ~actual:e.program;
  check_str "run_history merge full from" ~expected:"su-01" ~actual:e.from;
  check_str "run_history merge full to" ~expected:"su-02" ~actual:e.to_;
  check_str "run_history merge full backend" ~expected:"switch"
    ~actual:e.backend;
  check_bool "run_history merge full recorded" ~expected:true ~actual:e.recorded

let check_run_history_merge () =
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
  rm_rf dir;
  let watch_hub_port =
    match json with
    | `Assoc fs -> List.assoc_opt "watch_hub_port" fs
    | _ -> None
  in
  check_eq
    ~fmt:(Option.fold ~none:"None" ~some:Yojson.Safe.to_string)
    "run_history to_json includes watch_hub_port"
    ~expected:(Some (`Int Run_history.watch_hub_port))
    ~actual:watch_hub_port;
  match entries with
  | [ daemon_entry; full_entry ] ->
      check_merged_daemon_entry daemon_entry;
      check_merged_full_entry full_entry
  | _ ->
      Table_test.report "run_history merge returns two entries"
        (Error
           (Printf.sprintf "expected 2 entries, got %d" (List.length entries)))

let () =
  check_parse_tsv ();
  check_run_history_merge ();
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
    ]
