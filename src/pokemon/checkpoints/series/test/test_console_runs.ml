(* What the runner does around a run on the console: before each run (with or
   without already_at_start), and after it by its outcome, with and without
   saving after a pass. No fakes: pure functions on typed values. *)

open Checkpoints_series
module C = Console_runs

let show_steps l =
  match l with
  | [] -> "[]"
  | l -> "[" ^ String.concat "; " (List.map C.step_name l) ^ "]"

let check_eq name ~show ~expected ~actual =
  Table_test.report name
    (if actual = expected then Ok ()
     else
       Error
         (Printf.sprintf "expected %s, got %s" (show expected) (show actual)))

let () =
  check_eq "before run, not already at start: back to the last save"
    ~show:show_steps ~expected:[ C.Return_to_save ]
    ~actual:(C.before_run ~already_at_start:false);
  check_eq "before run, already at start: skip return to save" ~show:show_steps
    ~expected:[]
    ~actual:(C.before_run ~already_at_start:true);
  check_eq "passed, saving after a pass: save in game, keep the frame"
    ~show:show_steps
    ~expected:[ C.Save_in_game; C.Keep_start_frame ]
    ~actual:(C.after_run ~save_after_pass:true C.Passed);
  check_eq "passed, no save after a pass: nothing" ~show:show_steps ~expected:[]
    ~actual:(C.after_run ~save_after_pass:false C.Passed);
  check_eq "an event failed: back to the last save, never a save"
    ~show:show_steps ~expected:[ C.Return_to_save ]
    ~actual:(C.after_run ~save_after_pass:true C.Failed_event);
  check_eq "an end check failed: back to the last save, never a save"
    ~show:show_steps ~expected:[ C.Return_to_save ]
    ~actual:(C.after_run ~save_after_pass:true C.Failed_end_check);
  check_eq "stopped from the watch page: left where it stopped" ~show:show_steps
    ~expected:[]
    ~actual:(C.after_run ~save_after_pass:true C.Stopped);
  check_eq "unmet postconditions are an end check" ~show:C.outcome_name
    ~expected:C.Failed_end_check
    ~actual:
      (C.outcome_of_failure
         (Unmet_postconditions
            [ Engine_postcondition.Postcondition.not_read "money" ]));
  check_eq "no handler is an event failure" ~show:C.outcome_name
    ~expected:C.Failed_event
    ~actual:(C.outcome_of_failure (No_handler "walk"));
  Table_test.finish ()
