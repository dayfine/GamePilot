(* The words of a checkpoint run's summary line (Checkpoint_live_run): which
   run or round it was, its attempt, a repeating checkpoint's goal and a grind
   cap, each a note added to "PASS mg-04b round 3". *)

open Story

(* "mg-04b round 3" for a repeating checkpoint, else "mg-04a run 1". *)
let run_name id (plan : Plan.t) n =
  Printf.sprintf "%s %s %d" id (if plan.repeat = None then "run" else "round") n

(* " attempt 2/4" when the plan allows retries. *)
let attempt_note (plan : Plan.t) attempt =
  if plan.retries = 0 then ""
  else Printf.sprintf " attempt %d/%d" attempt (plan.retries + 1)

(* After a passing round: whether the goal holds now. *)
let goal_note = function
  | Some true -> " (goal met)"
  | Some false -> " (goal not met yet)"
  | None -> ""

(* With --grind-battles: " (grind capped at N; skipped: ...)", so a capped
   pass is never taken for a full one. *)
let capped_note ~grind_cap plan =
  let skipped cap =
    snd
      (Frlg_story.Checkpoint_run.capped_postconditions ~grind_cap:(Some cap)
         plan)
  in
  match grind_cap with
  | None -> ""
  | Some cap when skipped cap = [] -> Printf.sprintf " (grind capped at %d)" cap
  | Some cap ->
      Printf.sprintf " (grind capped at %d; skipped: %s)" cap
        (String.concat "; " (skipped cap))
