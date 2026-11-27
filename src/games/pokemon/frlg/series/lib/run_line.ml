(* FRLG-specific notes added to a checkpoint run's summary line
   (Checkpoint_live_run): a repeating checkpoint's goal and a grind cap. *)

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
      (Frlg_checkpoints.Checkpoint_run.capped_postconditions
         ~grind_cap:(Some cap) plan)
  in
  match grind_cap with
  | None -> ""
  | Some cap when skipped cap = [] -> Printf.sprintf " (grind capped at %d)" cap
  | Some cap ->
      Printf.sprintf " (grind capped at %d; skipped: %s)" cap
        (String.concat "; " (skipped cap))
