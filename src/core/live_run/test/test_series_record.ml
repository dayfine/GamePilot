(* What the watch page shows of a checkpoint series (Series_record), as the
   runner goes through it: each checkpoint's state, runs and times, the run
   going now, and the series' end. *)

module S = Series_record

let case name input expectation = { Table_test.name; input; expectation }

let info : Run_record.info =
  {
    kind = Checkpoints;
    program = [ ("game", "plza"); ("program", "plza.autostory") ];
    from_id = "01.00a";
    to_id = "01.01";
    backend = "switch";
    options = [];
  }

let series =
  S.create ~id:"s1" ~pid:42 info ~mode:"testing" ~started_ms:1000
    [ "01.00a"; "01.00b"; "01.01" ]

let run ?attempt name checkpoint ~started_ms : Run_record.run =
  {
    record = { dir = "/runs/" ^ name; name };
    info;
    checkpoint;
    mode = "testing";
    started_ms;
    attempt;
    events = None;
  }

let pass : Run_record.ending = { result = "pass"; at = ""; reason = "" }

let fail : Run_record.ending =
  { result = "fail"; at = "#2 talk"; reason = "no_text" }

let a1 = run "a1" "01.00a" ~started_ms:1000
let a2 = run ~attempt:(2, 3) "a2" "01.00a" ~started_ms:3000
let b1 = run "b1" "01.00b" ~started_ms:5000
let json t = Yojson.Safe.to_string (S.to_json t)

(* The members of a JSON object, none for anything else. *)
let members = function `Assoc fields -> fields | _ -> []

(* Member [name] of [fields] as JSON text, "absent" without it. *)
let member name fields =
  Option.fold ~none:"absent" ~some:Yojson.Safe.to_string
    (List.assoc_opt name fields)

let list_of name fields =
  match List.assoc_opt name fields with Some (`List l) -> l | _ -> []

let checkpoints t = list_of "checkpoints" (members (S.to_json t))

(* The series' field [name]. *)
let field name t = member name (members (S.to_json t))

(* Field [name] of each checkpoint, in the record's order. *)
let each_checkpoint name t =
  String.concat ", "
    (List.map (fun c -> member name (members c)) (checkpoints t))

let checkpoint_fields id t =
  List.find_opt
    (fun c -> member "id" (members c) = Printf.sprintf "%S" id)
    (checkpoints t)
  |> Option.fold ~none:[] ~some:members

(* Field [name] of checkpoint [id]. *)
let checkpoint id name t = member name (checkpoint_fields id t)

(* Field [name] of each run of checkpoint [id], in order. *)
let each_run id name t =
  String.concat ", "
    (List.map
       (fun r -> member name (members r))
       (list_of "runs" (checkpoint_fields id t)))

let in_a1 = S.begin_run series a1 ~n:1
let after_a1 = S.end_run in_a1 a1 fail ~now_ms:2000
let in_a2 = S.begin_run after_a1 a2 ~n:1
let after_a2 = S.end_run in_a2 a2 pass ~now_ms:4000
let in_b1 = S.begin_run after_a2 b1 ~n:1

let stopped =
  S.finish (S.end_run in_b1 b1 fail ~now_ms:6000) ~passed:false ~now_ms:6500

let passed =
  S.finish (S.end_run in_a1 a1 pass ~now_ms:2000) ~passed:true ~now_ms:2100

let generated =
  S.begin_run in_a1 (run "m1" "00-make-room" ~started_ms:1500) ~n:1

(* The series after each step, one fact per case. *)
let steps =
  [
    ("a new series: running", field "result" series, {|"running"|});
    ( "a new series: every checkpoint in run order",
      each_checkpoint "id" series,
      {|"01.00a", "01.00b", "01.01"|} );
    ( "a new series: every checkpoint to come",
      each_checkpoint "state" series,
      {|"pending", "pending", "pending"|} );
    ("a new series: no run going", field "run" series, "absent");
    ( "a run of the first checkpoint goes: it is current",
      checkpoint "01.00a" "state" in_a1,
      {|"current"|} );
    ( "a run of the first checkpoint goes: it started with the run",
      checkpoint "01.00a" "started_ms" in_a1,
      "1000" );
    ( "a run of the first checkpoint goes: the run named",
      field "run" in_a1,
      {|"a1"|} );
    ( "a run of the first checkpoint goes: its first attempt",
      each_run "01.00a" "attempt" in_a1,
      "1" );
    ( "a run of the first checkpoint goes: running",
      each_run "01.00a" "result" in_a1,
      {|"running"|} );
    ("a retry goes: both runs", each_run "01.00a" "run" in_a2, {|"a1", "a2"|});
    ( "a retry goes: the first failed, the retry running",
      each_run "01.00a" "result" in_a2,
      {|"fail", "running"|} );
    ( "a retry goes: the retry is attempt 2",
      each_run "01.00a" "attempt" in_a2,
      "1, 2" );
    ( "a retry goes: still current",
      checkpoint "01.00a" "state" in_a2,
      {|"current"|} );
    ("a retry goes: the retry named", field "run" in_a2, {|"a2"|});
    ("between runs: no run going", field "run" after_a2, "absent");
    ( "between runs: the checkpoint still current",
      checkpoint "01.00a" "state" after_a2,
      {|"current"|} );
    ( "between runs: the retry ended",
      each_run "01.00a" "ended_ms" after_a2,
      "2000, 4000" );
    ( "the next checkpoint's run goes: the one before passed",
      checkpoint "01.00a" "state" in_b1,
      {|"passed"|} );
    ( "the next checkpoint's run goes: the one before ended at its last run's \
       end",
      checkpoint "01.00a" "ended_ms" in_b1,
      "4000" );
    ( "the next checkpoint's run goes: it is current",
      checkpoint "01.00b" "state" in_b1,
      {|"current"|} );
    ( "the next checkpoint's run goes: it started with its run",
      checkpoint "01.00b" "started_ms" in_b1,
      "5000" );
    ( "the next checkpoint's run goes: the run named",
      field "run" in_b1,
      {|"b1"|} );
    ("the series stopped: failed", field "result" stopped, {|"fail"|});
    ("the series stopped: its end", field "ended_ms" stopped, "6500");
    ("the series stopped: no run going", field "run" stopped, "absent");
    ( "the series stopped: the one before still passed, the current checkpoint \
       failed, the rest skipped",
      each_checkpoint "state" stopped,
      {|"passed", "failed", "skipped"|} );
    ( "the series stopped: the current checkpoint ended with the series",
      checkpoint "01.00b" "ended_ms" stopped,
      "6500" );
    ("the series passed: passed", field "result" passed, {|"pass"|});
    ( "the series passed: the last checkpoint passed",
      checkpoint "01.00a" "state" passed,
      {|"passed"|} );
    ( "the series passed: the last checkpoint ended with the series",
      checkpoint "01.00a" "ended_ms" passed,
      "2100" );
    ( "a checkpoint the series did not list goes after the current one",
      each_checkpoint "id" generated,
      {|"01.00a", "00-make-room", "01.00b", "01.01"|} );
    ( "a checkpoint the series did not list: it is current",
      checkpoint "00-make-room" "state" generated,
      {|"current"|} );
    ( "a checkpoint the series did not list: the one before passed at its start",
      checkpoint "01.00a" "ended_ms" generated,
      "1500" );
    ( "a checkpoint the series did not list: its run named",
      field "run" generated,
      {|"m1"|} );
  ]
  |> List.map (fun (name, got, expect) -> case name (fun () -> got) expect)

(* The whole record of a stopped series: pins the series.json format the hub
   and the watch page read. *)
let format =
  [
    case "the format the hub and the watch page read"
      (fun () -> json stopped)
      {|{"series":"s1","pid":42,"game":"plza","program":"plza.autostory","from":"01.00a","to":"01.01","mode":"testing","backend":"switch","started_ms":1000,"ended_ms":6500,"result":"fail","checkpoints":[{"id":"01.00a","state":"passed","started_ms":1000,"ended_ms":4000,"runs":[{"run":"a1","n":1,"attempt":1,"started_ms":1000,"ended_ms":2000,"result":"fail","at":"#2 talk","reason":"no_text"},{"run":"a2","n":1,"attempt":2,"started_ms":3000,"ended_ms":4000,"result":"pass","at":"","reason":""}]},{"id":"01.00b","state":"failed","started_ms":5000,"ended_ms":6500,"runs":[{"run":"b1","n":1,"attempt":1,"started_ms":5000,"ended_ms":6000,"result":"fail","at":"#2 talk","reason":"no_text"}]},{"id":"01.01","state":"skipped","runs":[]}]}|};
  ]

let () = Table_test.run "series_record" (steps @ format)
