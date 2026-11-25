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

(* The series after each step, as the hub serves it. *)
let steps =
  let after_a1 = S.end_run (S.begin_run series a1 ~n:1) a1 fail ~now_ms:2000 in
  let in_a2 = S.begin_run after_a1 a2 ~n:1 in
  let after_a2 = S.end_run in_a2 a2 pass ~now_ms:4000 in
  let in_b1 = S.begin_run after_a2 b1 ~n:1 in
  [
    ( "a new series: every checkpoint to come, no run going",
      series,
      {|{"series":"s1","pid":42,"game":"plza","program":"plza.autostory","from":"01.00a","to":"01.01","mode":"testing","backend":"switch","started_ms":1000,"result":"running","checkpoints":[{"id":"01.00a","state":"pending","runs":[]},{"id":"01.00b","state":"pending","runs":[]},{"id":"01.01","state":"pending","runs":[]}]}|}
    );
    ( "a run of the first checkpoint goes: it is current, the run named",
      S.begin_run series a1 ~n:1,
      {|{"series":"s1","pid":42,"game":"plza","program":"plza.autostory","from":"01.00a","to":"01.01","mode":"testing","backend":"switch","started_ms":1000,"result":"running","run":"a1","checkpoints":[{"id":"01.00a","state":"current","started_ms":1000,"runs":[{"run":"a1","n":1,"attempt":1,"started_ms":1000,"result":"running"}]},{"id":"01.00b","state":"pending","runs":[]},{"id":"01.01","state":"pending","runs":[]}]}|}
    );
    ( "its attempt failed and a retry goes: both runs, still current",
      in_a2,
      {|{"series":"s1","pid":42,"game":"plza","program":"plza.autostory","from":"01.00a","to":"01.01","mode":"testing","backend":"switch","started_ms":1000,"result":"running","run":"a2","checkpoints":[{"id":"01.00a","state":"current","started_ms":1000,"runs":[{"run":"a1","n":1,"attempt":1,"started_ms":1000,"ended_ms":2000,"result":"fail","at":"#2 talk","reason":"no_text"},{"run":"a2","n":1,"attempt":2,"started_ms":3000,"result":"running"}]},{"id":"01.00b","state":"pending","runs":[]},{"id":"01.01","state":"pending","runs":[]}]}|}
    );
    ( "between runs: no run going",
      after_a2,
      {|{"series":"s1","pid":42,"game":"plza","program":"plza.autostory","from":"01.00a","to":"01.01","mode":"testing","backend":"switch","started_ms":1000,"result":"running","checkpoints":[{"id":"01.00a","state":"current","started_ms":1000,"runs":[{"run":"a1","n":1,"attempt":1,"started_ms":1000,"ended_ms":2000,"result":"fail","at":"#2 talk","reason":"no_text"},{"run":"a2","n":1,"attempt":2,"started_ms":3000,"ended_ms":4000,"result":"pass","at":"","reason":""}]},{"id":"01.00b","state":"pending","runs":[]},{"id":"01.01","state":"pending","runs":[]}]}|}
    );
    ( "the next checkpoint's run goes: the one before passed at its last run's \
       end",
      in_b1,
      {|{"series":"s1","pid":42,"game":"plza","program":"plza.autostory","from":"01.00a","to":"01.01","mode":"testing","backend":"switch","started_ms":1000,"result":"running","run":"b1","checkpoints":[{"id":"01.00a","state":"passed","started_ms":1000,"ended_ms":4000,"runs":[{"run":"a1","n":1,"attempt":1,"started_ms":1000,"ended_ms":2000,"result":"fail","at":"#2 talk","reason":"no_text"},{"run":"a2","n":1,"attempt":2,"started_ms":3000,"ended_ms":4000,"result":"pass","at":"","reason":""}]},{"id":"01.00b","state":"current","started_ms":5000,"runs":[{"run":"b1","n":1,"attempt":1,"started_ms":5000,"result":"running"}]},{"id":"01.01","state":"pending","runs":[]}]}|}
    );
    ( "the series stopped: the current checkpoint failed, the rest skipped",
      S.finish (S.end_run in_b1 b1 fail ~now_ms:6000) ~passed:false ~now_ms:6500,
      {|{"series":"s1","pid":42,"game":"plza","program":"plza.autostory","from":"01.00a","to":"01.01","mode":"testing","backend":"switch","started_ms":1000,"ended_ms":6500,"result":"fail","checkpoints":[{"id":"01.00a","state":"passed","started_ms":1000,"ended_ms":4000,"runs":[{"run":"a1","n":1,"attempt":1,"started_ms":1000,"ended_ms":2000,"result":"fail","at":"#2 talk","reason":"no_text"},{"run":"a2","n":1,"attempt":2,"started_ms":3000,"ended_ms":4000,"result":"pass","at":"","reason":""}]},{"id":"01.00b","state":"failed","started_ms":5000,"ended_ms":6500,"runs":[{"run":"b1","n":1,"attempt":1,"started_ms":5000,"ended_ms":6000,"result":"fail","at":"#2 talk","reason":"no_text"}]},{"id":"01.01","state":"skipped","runs":[]}]}|}
    );
    ( "the series passed: the last checkpoint passed",
      S.finish
        (S.end_run (S.begin_run series a1 ~n:1) a1 pass ~now_ms:2000)
        ~passed:true ~now_ms:2100,
      {|{"series":"s1","pid":42,"game":"plza","program":"plza.autostory","from":"01.00a","to":"01.01","mode":"testing","backend":"switch","started_ms":1000,"ended_ms":2100,"result":"pass","checkpoints":[{"id":"01.00a","state":"passed","started_ms":1000,"ended_ms":2100,"runs":[{"run":"a1","n":1,"attempt":1,"started_ms":1000,"ended_ms":2000,"result":"pass","at":"","reason":""}]},{"id":"01.00b","state":"pending","runs":[]},{"id":"01.01","state":"pending","runs":[]}]}|}
    );
    ( "a run of a checkpoint the series did not list goes after the current one",
      S.begin_run
        (S.begin_run series a1 ~n:1)
        (run "m1" "00-make-room" ~started_ms:1500)
        ~n:1,
      {|{"series":"s1","pid":42,"game":"plza","program":"plza.autostory","from":"01.00a","to":"01.01","mode":"testing","backend":"switch","started_ms":1000,"result":"running","run":"m1","checkpoints":[{"id":"01.00a","state":"passed","started_ms":1000,"ended_ms":1500,"runs":[{"run":"a1","n":1,"attempt":1,"started_ms":1000,"result":"running"}]},{"id":"00-make-room","state":"current","started_ms":1500,"runs":[{"run":"m1","n":1,"attempt":1,"started_ms":1500,"result":"running"}]},{"id":"01.00b","state":"pending","runs":[]},{"id":"01.01","state":"pending","runs":[]}]}|}
    );
  ]
  |> List.map (fun (name, t, expect) -> case name (fun () -> json t) expect)

let () = Table_test.run "series_record" steps
