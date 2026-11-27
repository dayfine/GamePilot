module P = Plza_engine
module Game = Plza_bank_home.Bank_home_game
module Series = Plza_checkpoint_series.Checkpoint_series
module Attempts = Plza_checkpoint_series.Run_attempts

let ( let* ) = Result.bind

(* The start check's failure, as the runner names one before the first
   event. *)
let at_start (checkpoint : P.Plan.checkpoint) cause : P.Failure.t =
  {
    checkpoint_id = checkpoint.checkpoint_id;
    event_index = 0;
    event_id = "start";
    reason = Handler cause;
  }

let run_checkpoint ~log ~picture ~moves templates report (plan : P.Plan.t) =
  let game = Game.make ~log ~picture ~moves templates in
  P.Plan_watch.run ~mode:"testing" report (fun ~on_event ->
      let* () =
        Result.map_error (at_start plan.checkpoint)
          (Game.start_check ~log templates)
      in
      P.Runner.run ~on_event game plan.checkpoint)

(* One attempt: Pokémon HOME's templates read and the checkpoint run. Its
   start check reaches its start from anywhere, so a reload asks nothing
   more. *)
let attempt moves ~log ~picture ~reload:_ report plan : Attempts.outcome =
  match Home_templates.load () with
  | Error e -> Series.failed ~repeats:true "assets" e
  | Ok templates -> (
      match run_checkpoint ~log ~picture ~moves templates report plan with
      | Ok () -> Passed
      | Error f -> Attempts.of_failure f)

let bank_home moves : Series.program =
  {
    check_plans = Series.each_plan Game.check_plan;
    with_end_place = Series.no_end_place;
    daemon_flags = [];
    initial_screen = (fun _ -> Switch.Initial_screen.In_game_or_home);
    attempt = attempt moves;
  }

let run_series ~moves ~program ~options ~viewport plan_dir args =
  Series.run_series (bank_home moves) ~program_fields:program ~options ~viewport
    plan_dir args
