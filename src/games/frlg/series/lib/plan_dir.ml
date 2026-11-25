(* A program's plan folder (Engine_series.Plan_folder) with FRLG's plans
   loaded from it, and the plan before one. *)

open Pokemon_engine
include Engine_series.Plan_folder

let ( let* ) = Result.bind

let load_plan ~plan_dir id =
  let* plan = Frlg_checkpoints.Plan_file.load (plan_file ~plan_dir id) in
  let* () = Frlg_checkpoints.Checkpoint_run.check_plan plan in
  Ok plan

(* What the checkpoint before [id] promised: its postconditions. *)
let promised_before ~plan_dir id =
  let* ids = checkpoint_ids plan_dir in
  match previous ids id with
  | None -> Ok None
  | Some p ->
      Result.map
        (fun (plan : Plan.t) ->
          Some (Postconditions.stated plan.postconditions))
        (load_plan ~plan_dir p)
