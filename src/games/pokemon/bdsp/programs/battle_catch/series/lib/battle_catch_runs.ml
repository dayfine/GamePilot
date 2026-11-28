module Series = Bdsp_checkpoint_series.Checkpoint_series

let run_battle_catch ~log ~picture ~options () =
  let passed, line = Bdsp_battle_catch.Battle_catch.run ~picture ~options () in
  log line;
  if passed then Ok ()
  else Error (Engine_run.Failure.cause ~repeats:true "battle_catch_paused" line)

let run_action ~log ~picture ~options = function
  | Bdsp_rules.Action.Save_game -> Series.run_save_game ~log ~picture ()
  | Bdsp_rules.Action.Battle_catch -> run_battle_catch ~log ~picture ~options ()
  | _ ->
      Error
        (Engine_run.Failure.cause ~repeats:true "unexpected_action"
           "bdsp.battle_catch does not handle this action")

let run_series ~program ~options ~viewport plan_dir args =
  Series.run_series
    (Series.default_program ~run_action)
    ~program_fields:program ~options ~viewport plan_dir args
