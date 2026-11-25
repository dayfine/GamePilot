open Pokemon_checkpoints

type outcome = Passed | Failed_event | Failed_end_check | Stopped
type step = Return_to_save | Save_in_game | Keep_start_frame

let before_run = [ Return_to_save ]

let after_run ~save_after_pass = function
  | Passed when save_after_pass -> [ Save_in_game; Keep_start_frame ]
  | Passed -> []
  | Failed_event | Failed_end_check -> [ Return_to_save ]
  | Stopped -> []

let outcome_of_failure : Failure.reason -> outcome = function
  | Not_at_end _ | Unmet_postconditions _ -> Failed_end_check
  | Handler _ | No_handler _ | Not_at_declared _ -> Failed_event

let step_name = function
  | Return_to_save -> "return to the last save"
  | Save_in_game -> "save in the game"
  | Keep_start_frame -> "keep the start frame"

let outcome_name = function
  | Passed -> "passed"
  | Failed_event -> "an event failed"
  | Failed_end_check -> "an end check failed"
  | Stopped -> "stopped"
