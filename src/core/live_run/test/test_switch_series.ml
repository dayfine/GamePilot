(* Typed unit tests for Live_run.Switch_series.ending_of. *)

type outcome = Passed | Failed of { at : string; reason : string }

let result_of = function
  | Passed -> Ok ()
  | Failed { at; reason } -> Error (at, reason)

let check_eq name ~expected actual =
  Table_test.report name
    (if actual = expected then Ok ()
     else Error "Switch_series.ending_of did not match expected value")

let () =
  check_eq "ending_of formats passing outcome"
    ~expected:
      ( "PASS 01-save run 1",
        { Run_record.result = "pass"; at = ""; reason = "" } )
    (Switch_series.ending_of ~result_of "01-save run 1" Passed);
  check_eq "ending_of formats failing outcome"
    ~expected:
      ( "FAIL 01-save run 1 at #1 save: timeout",
        { Run_record.result = "fail"; at = "#1 save"; reason = "timeout" } )
    (Switch_series.ending_of ~result_of "01-save run 1"
       (Failed { at = "#1 save"; reason = "timeout" }));
  Table_test.finish ()
