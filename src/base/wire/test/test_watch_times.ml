(* The plan's event times (watch.plan v1.8): how a state change stamps an
   event, and the times the page and [gamepilot runs] show from them. *)

open Wire.Watch

let ms = function None -> "none" | Some n -> string_of_int n
let times e = Printf.sprintf "%s..%s" (ms e.started_ms) (ms e.ended_ms)

(* [steps] applied in order, each (state, at ms). *)
let stamped steps =
  times
    (List.fold_left
       (fun e (state, now_ms) -> stamp ~now_ms e state "")
       (pending "walk") steps)

let event ?started ?ended state =
  { (pending "e") with state; started_ms = started; ended_ms = ended }

let plan events = { checkpoint = "mg-01"; events }
let live = Some 5000

let cases : Table_test.case list =
  [
    {
      name = "stamp: a pending event has no times";
      input = (fun () -> stamped []);
      expectation = "none..none";
    };
    {
      name = "stamp: starting sets the start";
      input = (fun () -> stamped [ (Current, 100) ]);
      expectation = "100..none";
    };
    {
      name = "stamp: passing keeps the start and sets the end";
      input = (fun () -> stamped [ (Current, 100); (Done, 900) ]);
      expectation = "100..900";
    };
    {
      name = "stamp: failing sets the end too";
      input = (fun () -> stamped [ (Current, 100); (Failed, 400) ]);
      expectation = "100..400";
    };
    {
      name = "stamp: a skip that never started took no time";
      input = (fun () -> stamped [ (Skipped, 700) ]);
      expectation = "700..700";
    };
    {
      name = "stamp: starting again restarts the clock";
      input =
        (fun () -> stamped [ (Current, 100); (Failed, 400); (Current, 600) ]);
      expectation = "600..none";
    };
    {
      name = "event_ms: a finished event, start to end";
      input =
        (fun () ->
          ms (event_ms ~now_ms:live (event ~started:1000 ~ended:4200 Done)));
      expectation = "3200";
    };
    {
      name = "event_ms: the current event, start to now";
      input =
        (fun () -> ms (event_ms ~now_ms:live (event ~started:1000 Current)));
      expectation = "4000";
    };
    {
      name = "event_ms: the current event of a plan that is not live";
      input =
        (fun () -> ms (event_ms ~now_ms:None (event ~started:1000 Current)));
      expectation = "none";
    };
    {
      name = "event_ms: a pending event, or one from a v1.7 program";
      input = (fun () -> ms (event_ms ~now_ms:live (event Pending)));
      expectation = "none";
    };
    {
      name = "plan_ms: running, first start to now";
      input =
        (fun () ->
          ms
            (plan_ms ~now_ms:live
               (plan
                  [
                    event ~started:1000 ~ended:2000 Done;
                    event ~started:2500 Current;
                    event Pending;
                  ])));
      expectation = "4000";
    };
    {
      name = "plan_ms: finished, first start to last end (gaps included)";
      input =
        (fun () ->
          ms
            (plan_ms ~now_ms:live
               (plan
                  [
                    event ~started:1000 ~ended:2000 Done;
                    event ~started:2500 ~ended:2500 Skipped;
                    event ~started:3000 ~ended:4500 Failed;
                    event Pending;
                  ])));
      expectation = "3500";
    };
    {
      name = "plan_ms: a past plan left running counts to its last end";
      input =
        (fun () ->
          ms
            (plan_ms ~now_ms:None
               (plan
                  [
                    event ~started:1000 ~ended:2000 Done;
                    event ~started:2500 Current;
                  ])));
      expectation = "1000";
    };
    {
      name = "plan_ms: nothing started";
      input = (fun () -> ms (plan_ms ~now_ms:live (plan [ event Pending ])));
      expectation = "none";
    };
  ]

let () = Table_test.run "watch_times" cases
