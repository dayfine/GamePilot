(* run.json for every run path (Run_record.run_json), the files a finished
   run leaves (start, finish), folder names, and what an old folder says of
   its run (Folder_facts). *)

module R = Run_record

let case name input expectation = { Case_table.name; input; expectation }
let mail_glitch = [ ("game", "frlg"); ("program", "frlg.mail_glitch") ]

let info kind ~program ~from_id ~to_id ~backend : R.info =
  { kind; program; from_id; to_id; backend }

let run_of info ~name ~checkpoint ~mode : R.run =
  {
    record = { dir = "/runs/" ^ name; name };
    info;
    checkpoint;
    mode;
    started_ms = 1000;
  }

let json run ending =
  Yojson.Safe.to_string (R.run_json run ~ended_ms:2000 ending)

let fail = Some { R.result = "fail"; at = "#2 talk"; reason = "no_text" }

(* Each run path's run.json, at the start and with its result. *)
let paths =
  [
    ( "a series' run, at the start",
      run_of
        (info Checkpoints ~program:mail_glitch ~from_id:"mg-01" ~to_id:"mg-03"
           ~backend:"switch")
        ~name:"r" ~checkpoint:"mg-02" ~mode:"testing",
      None,
      {|{"run":"r","kind":"checkpoints","game":"frlg","program":"frlg.mail_glitch","from":"mg-01","to":"mg-03","checkpoint":"mg-02","backend":"switch","mode":"testing","started_ms":1000}|}
    );
    ( "a series' run, failed",
      run_of
        (info Checkpoints ~program:mail_glitch ~from_id:"mg-01" ~to_id:"mg-03"
           ~backend:"mgba")
        ~name:"r" ~checkpoint:"mg-02" ~mode:"verification",
      fail,
      {|{"run":"r","kind":"checkpoints","game":"frlg","program":"frlg.mail_glitch","from":"mg-01","to":"mg-03","checkpoint":"mg-02","backend":"mgba","mode":"verification","started_ms":1000,"ended_ms":2000,"result":"fail","at":"#2 talk","reason":"no_text"}|}
    );
    ( "the pre-flight",
      run_of
        (info Preflight ~program:mail_glitch ~from_id:"mg-01" ~to_id:"mg-01"
           ~backend:"switch")
        ~name:"p" ~checkpoint:"mg-01" ~mode:"preflight",
      Some { R.result = "pass"; at = ""; reason = "" },
      {|{"run":"p","kind":"preflight","game":"frlg","program":"frlg.mail_glitch","from":"mg-01","to":"mg-01","checkpoint":"mg-01","backend":"switch","mode":"preflight","started_ms":1000,"ended_ms":2000,"result":"pass","at":"","reason":""}|}
    );
    ( "one checkpoint of no program",
      run_of
        (info Checkpoint ~program:[] ~from_id:"x" ~to_id:"x" ~backend:"")
        ~name:"c" ~checkpoint:"x" ~mode:"single",
      None,
      {|{"run":"c","kind":"checkpoint","game":"","program":"","from":"x","to":"x","checkpoint":"x","backend":"","mode":"single","started_ms":1000}|}
    );
    ( "a one-shot program",
      run_of
        (info Program
           ~program:[ ("game", "frlg"); ("program", "frlg.start_menu_poc") ]
           ~from_id:"frlg.start_menu_poc" ~to_id:"frlg.start_menu_poc"
           ~backend:"")
        ~name:"g" ~checkpoint:"frlg.start_menu_poc" ~mode:"run",
      None,
      {|{"run":"g","kind":"program","game":"frlg","program":"frlg.start_menu_poc","from":"frlg.start_menu_poc","to":"frlg.start_menu_poc","checkpoint":"frlg.start_menu_poc","backend":"","mode":"run","started_ms":1000}|}
    );
    ( "the bring-up checks",
      run_of
        (info Bring_up ~program:[] ~from_id:"" ~to_id:"" ~backend:"switch")
        ~name:"b" ~checkpoint:"switch" ~mode:"bring-up",
      fail,
      {|{"run":"b","kind":"bring-up","game":"","program":"","from":"","to":"","checkpoint":"switch","backend":"switch","mode":"bring-up","started_ms":1000,"ended_ms":2000,"result":"fail","at":"#2 talk","reason":"no_text"}|}
    );
  ]
  |> List.map (fun (name, run, ending, expect) ->
         case name (fun () -> json run ending) expect)

let names =
  [
    ("a series' run", "2026-11-23-mg-05a-verification-12", "mg-05a verification");
    ("the pre-flight", "2026-11-23-mg-01-preflight-1", "mg-01 preflight");
    ("the bring-up checks", "2026-11-23-switch-bring-up-2", "switch bring-up");
    ( "a one-shot program",
      "2026-11-23-frlg.start_menu_poc-run-1",
      "frlg.start_menu_poc run" );
    ("a hand-made folder", "2026-11-23-switch-idle-3", "none");
    ("no date", "mg-07-testing-1", "none");
  ]
  |> List.map (fun (name, input, expect) ->
         case name
           (fun () ->
             match R.parse_name input with
             | Some (label, mode) -> label ^ " " ^ mode
             | None -> "none")
           expect)

let read path = In_channel.with_open_bin path In_channel.input_all

let temp_dir () =
  let dir = Filename.temp_file "run_record" "" in
  Sys.remove dir;
  dir

(* A run started and finished in a scratch runs folder: the files on disk. *)
let finished ending () =
  let runs_dir = temp_dir () in
  let info =
    info Preflight ~program:[] ~from_id:"mg-01" ~to_id:"mg-01" ~backend:"mgba"
  in
  let run = R.start ~runs_dir info ~checkpoint:"mg-01" ~mode:"preflight" in
  let started = read (R.path run.record "run.json") in
  R.finish ~runs_dir run ~summary:"table\nPREFLIGHT verdict" ending;
  let ended = Yojson.Safe.from_string (read (R.path run.record "run.json")) in
  let field k = Yojson.Safe.Util.(member k ended |> to_string) in
  let rows =
    String.split_on_char '\n' (read (Filename.concat runs_dir "RESULTS.tsv"))
  in
  String.concat "; "
    [
      (if String.length started > 0 then "started" else "no start");
      field "kind" ^ " " ^ field "mode" ^ " " ^ field "result";
      String.trim (read (R.path run.record "summary.txt"));
      (if Sys.file_exists (R.path run.record "KEEP") then "KEEP" else "no KEEP");
      string_of_int (List.length (List.filter (( <> ) "") rows)) ^ " rows";
    ]

let files =
  [
    case "a pass: run.json, summary, RESULTS.tsv"
      (finished { result = "pass"; at = ""; reason = "" })
      "started; preflight preflight pass; table\n\
       PREFLIGHT verdict; no KEEP; 2 rows";
    case "a failure: and KEEP"
      (finished { result = "fail"; at = "preflight"; reason = "mismatch" })
      "started; preflight preflight fail; table\n\
       PREFLIGHT verdict; KEEP; 2 rows";
  ]

(* An old folder's times: daemon.json's zero and the wire log's last line;
   the pre-flight's verdict from its story.log. *)
let folder_with files () =
  let dir = temp_dir () in
  Sys.mkdir dir 0o755;
  List.iter
    (fun (name, text) ->
      Out_channel.with_open_bin (Filename.concat dir name) (fun out ->
          Out_channel.output_string out text))
    files;
  Yojson.Safe.to_string (`Assoc (R.Folder_facts.of_folder dir))

let wire = {|{"t_ms":10.0}
{"t_ms":65000.5}
|}

let facts =
  [
    case "daemon.json and the wire log"
      (folder_with
         [
           ( "daemon.json",
             {|{"backend":"switch","clock_zero_unix_ms":1795500000000}|} );
           ("wire.jsonl", wire);
         ])
      {|{"backend":"switch","started_ms":1795500000000,"ended_ms":1795500065000}|};
    case "the backend from daemon.out"
      (folder_with
         [
           ("daemon.json", {|{"clock_zero_unix_ms":5}|});
           ("daemon.out", "board: DTR = 1\n");
         ])
      {|{"backend":"switch","started_ms":5}|};
  ]

let verdicts =
  [
    ( "passed",
      [ "x"; "[Preflight] mg-01: the save holds what it needs" ],
      {|[["result","pass"]]|} );
    ( "a mismatch",
      [ "[Preflight] mg-01: MISMATCH: not starting" ],
      {|[["result","fail"],["at","preflight"],["reason","MISMATCH: not starting"]]|}
    );
    ("never finished", [ "Soft reset: A + B + SELECT + START." ], "[]");
  ]
  |> List.map (fun (name, lines, expect) ->
         case ("pre-flight " ^ name)
           (fun () ->
             R.Folder_facts.preflight_verdict "mg-01" lines
             |> List.map (fun (k, v) -> `List [ `String k; v ])
             |> fun l -> Yojson.Safe.to_string (`List l))
           expect)

let () = Case_table.run "run_record" (paths @ names @ files @ facts @ verdicts)
