(** A program's plan folder (Engine_series.Plan_folder) with FRLG's plans loaded
    from it. *)

include module type of struct
  include Engine_series.Plan_folder
end

val load_plan :
  plan_dir:string -> string -> (Pokemon_checkpoints.Plan.t, string) result
(** The checkpoint's plan, loaded and checked
    (Frlg_checkpoints.Checkpoint_run.check_plan). *)

val promised_before :
  plan_dir:string ->
  string ->
  (Pokemon_checkpoints.Postconditions.t option, string) result
(** What the checkpoint before it promised: its stated postconditions. *)
