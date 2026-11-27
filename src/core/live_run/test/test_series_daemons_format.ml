(* Typed unit tests for Series_daemons.run_name and Series_daemons.format_ending. *)

let check_string name actual expected =
  Table_test.report name
    (if actual = expected then Ok ()
     else Error (Printf.sprintf "expected %S, got %S" expected actual))

let check_ending name actual expected =
  Table_test.report name
    (if actual = expected then Ok ()
     else
       let s1, (e1 : Run_record.ending) = expected in
       let s2, (e2 : Run_record.ending) = actual in
       Error
         (Printf.sprintf "expected (%S, {%s,%s,%s}), got (%S, {%s,%s,%s})" s1
            e1.result e1.at e1.reason s2 e2.result e2.at e2.reason))

let () =
  check_string "run_name default attempt 1 omits attempt"
    (Series_daemons.run_name ~id:"03.02-out" ~n:1 ~attempt:1 ())
    "03.02-out run 1";
  check_string "run_name default attempt > 1 includes attempt"
    (Series_daemons.run_name ~id:"03.02-out" ~n:2 ~attempt:3 ())
    "03.02-out run 2 attempt 3";
  check_string "run_name with attempts=1 omits attempt"
    (Series_daemons.run_name ~unit_name:"run" ~attempts:1 ~id:"04-grind" ~n:1
       ~attempt:1 ())
    "04-grind run 1";
  check_string "run_name with round and attempts>1 formats attempt/total"
    (Series_daemons.run_name ~unit_name:"round" ~attempts:4 ~id:"05-grind" ~n:3
       ~attempt:2 ())
    "05-grind round 3 attempt 2/4";
  check_ending "format_ending pass without suffix"
    (Series_daemons.format_ending ~name:"03.02 run 1" (Ok ()))
    ("PASS 03.02 run 1", { Run_record.result = "pass"; at = ""; reason = "" });
  check_ending "format_ending pass with suffix"
    (Series_daemons.format_ending ~name:"05-grind round 3"
       ~suffix:" (goal met) (grind capped at 2)" (Ok ()))
    ( "PASS 05-grind round 3 (goal met) (grind capped at 2)",
      { Run_record.result = "pass"; at = ""; reason = "" } );
  check_ending "format_ending fail without suffix"
    (Series_daemons.format_ending ~name:"03.02 run 1"
       (Error ("#4 walk", "timed out")))
    ( "FAIL 03.02 run 1 at #4 walk: timed out",
      { Run_record.result = "fail"; at = "#4 walk"; reason = "timed out" } );
  check_ending "format_ending fail with suffix"
    (Series_daemons.format_ending ~name:"05-grind round 1"
       ~suffix:" (grind capped at 2)"
       (Error ("start", "off start")))
    ( "FAIL 05-grind round 1 at start: off start (grind capped at 2)",
      { Run_record.result = "fail"; at = "start"; reason = "off start" } );
  Table_test.finish ()
