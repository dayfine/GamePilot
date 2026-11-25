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

let cases =
  [
    case "before every run: back to the last save"
      (fun () -> steps C.before_run)
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
