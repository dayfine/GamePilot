(* A series' record where the hub reads it (Series_watch): written at the
   start, rewritten at each change, none without a watch page. *)

let info : Run_record.info =
  {
    kind = Checkpoints;
    program = [ ("game", "frlg"); ("program", "frlg.mail_glitch") ];
    from_id = "mg-01";
    to_id = "mg-02";
    backend = "mgba";
  }

let temp_dir () =
  let dir = Filename.temp_file "series_watch" "" in
  Sys.remove dir;
  dir

let watch registry : Daemon_process.watch =
  { listen = "127.0.0.1"; port = 0; token = "t"; registry }

let run name : Run_record.run =
  {
    record = { dir = "/runs/" ^ name; name };
    info;
    checkpoint = "mg-01";
    mode = "testing";
    started_ms = 1000;
    attempt = None;
    events = None;
  }

(* The record's field [name], as JSON text, or "none" with no file. *)
let field registry series name =
  match Series_watch.id series with
  | None -> "no id"
  | Some id -> (
      let path = Series_watch.file ~registry id in
      match Yojson.Safe.from_file path with
      | `Assoc fields ->
          Option.fold ~none:"absent" ~some:Yojson.Safe.to_string
            (List.assoc_opt name fields)
      | _ -> "not an object"
      | exception Sys_error _ -> "none")

let expect what got want =
  Table_test.report what
    (if got = want then Ok () else Error (Printf.sprintf "%s, not %s" got want))

let () =
  let registry = temp_dir () in
  let series =
    Series_watch.start
      (Some (watch registry))
      info ~mode:"testing" [ "mg-01"; "mg-02" ]
  in
  expect "started: the series is running"
    (field registry series "result")
    {|"running"|};
  expect "started: its pid is the runner's"
    (field registry series "pid")
    (string_of_int (Unix.getpid ()));
  Series_watch.run_started series (run "r1") ~n:1;
  expect "a run started: it is the one going"
    (field registry series "run")
    {|"r1"|};
  Series_watch.run_ended series (run "r1")
    { result = "pass"; at = ""; reason = "" };
  expect "the run ended: none going" (field registry series "run") "absent";
  Series_watch.finished series ~passed:true;
  expect "finished: passed" (field registry series "result") {|"pass"|};
  let unwatched = Series_watch.start None info ~mode:"testing" [ "mg-01" ] in
  Series_watch.run_started unwatched (run "r2") ~n:1;
  expect "no watch page: no record" (field registry unwatched "result") "no id";
  Table_test.finish ()
