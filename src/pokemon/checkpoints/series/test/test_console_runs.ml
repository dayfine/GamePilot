(* What the runner does around a run on the console: before each run, and
   after it by its outcome, with and without saving after a pass. *)

open Checkpoints_series
module C = Console_runs

let steps l =
  match l with
  | [] -> "nothing"
  | l -> String.concat ", " (List.map C.step_name l)

let case name input expectation = { Table_test.name; input; expectation }
let after save outcome () = steps (C.after_run ~save_after_pass:save outcome)

let before ~continuing_from_pass ~trial ~attempt () =
  let already_at_start =
    C.already_at_start ~continuing_from_pass ~trial ~attempt
  in
  steps (C.before_run ~already_at_start)

let cases =
  [
    case "cold start (first checkpoint): back to the last save"
      (before ~continuing_from_pass:false ~trial:1 ~attempt:1)
      (steps [ C.Return_to_save ]);
    case "continuing from a passing checkpoint: skip soft reset"
      (before ~continuing_from_pass:true ~trial:1 ~attempt:1)
      "nothing";
    case "retry after failure: back to the last save"
      (before ~continuing_from_pass:true ~trial:1 ~attempt:2)
      (steps [ C.Return_to_save ]);
    case "verification trial after trial 1: back to the last save"
      (before ~continuing_from_pass:true ~trial:2 ~attempt:1)
      (steps [ C.Return_to_save ]);
    case "verification trial after trial 1 on cold start: back to the last save"
      (before ~continuing_from_pass:false ~trial:2 ~attempt:1)
      (steps [ C.Return_to_save ]);
    case "passed, saving after a pass: save in game, keep the frame"
      (after true C.Passed)
      (steps [ C.Save_in_game; C.Keep_start_frame ]);
    case "passed, no save after a pass: nothing" (after false C.Passed)
      "nothing";
    case "an event failed: back to the last save, never a save"
      (after true C.Failed_event)
      (steps [ C.Return_to_save ]);
    case "an end check failed: back to the last save, never a save"
      (after true C.Failed_end_check)
      (steps [ C.Return_to_save ]);
    case "stopped from the watch page: left where it stopped"
      (after true C.Stopped) "nothing";
    case "unmet postconditions are an end check"
      (fun () ->
        C.outcome_name
          (C.outcome_of_failure
             (Unmet_postconditions
                [ Engine_postcondition.Postcondition.not_read "money" ])))
      (C.outcome_name C.Failed_end_check);
    case "no handler is an event failure"
      (fun () -> C.outcome_name (C.outcome_of_failure (No_handler "walk")))
      (C.outcome_name C.Failed_event);
  ]

let () = Table_test.run "console runs" cases
