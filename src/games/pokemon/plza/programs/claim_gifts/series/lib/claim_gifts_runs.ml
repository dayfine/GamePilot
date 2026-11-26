module P = Plza_engine
module Series = Plza_checkpoint_series.Checkpoint_series
module Attempts = Plza_checkpoint_series.Run_attempts

type inputs = {
  catalog : Plza_gift_catalog.Gift_catalog.t;
  today : Plza_gift_catalog.Gift_catalog.date;
  name_templates : (string * string) list;
}

let run_checkpoint inputs ~log ~picture ~assets report (plan : P.Plan.t) =
  let game =
    Plza_claim_gifts.Live_gift_steps.game ~catalog:inputs.catalog
      ~today:inputs.today ~name_templates:inputs.name_templates ~log ~picture
      ~assets
  in
  (* A console idle before the run dims its screen; nothing reads on it. *)
  Switch_home.Stick_wake.run ();
  P.Plan_watch.run ~mode:"testing" report (fun ~on_event ->
      P.Runner.run ~on_event game plan.checkpoint)

(* One attempt: the readers' templates uploaded and the checkpoint run. A
   reload is never asked for: its start check reaches the main menu from the
   overworld. *)
let attempt inputs ~log ~picture ~reload:_ report plan : Attempts.outcome =
  match Plza_checkpoint_series.Templates.upload () with
  | Error e -> Series.failed ~repeats:true "assets" e
  | Ok assets -> (
      match run_checkpoint inputs ~log ~picture ~assets report plan with
      | Ok () -> Passed
      | Error f -> Attempts.of_failure f)

let run_series inputs ~program ~options ~viewport plan_dir args =
  Series.run_series
    {
      check_plans = Series.each_plan Plza_claim_gifts.Claim_gifts.check_plan;
      with_end_place = Series.no_end_place;
      daemon_flags = Series.keepawake_stick;
      attempt = attempt inputs;
    }
    ~program_fields:program ~options ~viewport plan_dir args
