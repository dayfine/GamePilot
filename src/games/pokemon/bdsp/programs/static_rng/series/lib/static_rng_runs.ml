module Series = Bdsp_checkpoint_series.Checkpoint_series

let run_action ~log ~picture ~options = function
  | Bdsp_rules.Action.Save_game -> Series.run_save_game ~log ~picture ()
  | Bdsp_rules.Action.Static_rng ->
      Bdsp_static_rng.Static_rng.run_action ~log ~picture ~options
  | Bdsp_rules.Action.Underground_farm ->
      Error
        (Engine_run.Failure.cause ~repeats:true "unexpected_action"
           "bdsp.static_rng does not handle underground_farm actions")

let run_series ~program ~options ~viewport plan_dir args =
  Series.run_series
    (Series.default_program ~run_action)
    ~program_fields:program ~options ~viewport plan_dir args
