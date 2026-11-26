module P = Plza_engine
module Story = Plza_autostory
module Series = Plza_checkpoint_series.Checkpoint_series
module Attempts = Plza_checkpoint_series.Run_attempts

let ( let* ) = Result.bind
let failed = Series.failed

let reload_cause ~log ~picture () =
  Result.map_error
    (fun e -> Engine_run.Failure.cause "reload_failed" e)
    (Story.Game_reload.reload ~log ~picture)

let unreachable (plan : P.Plan.t) =
  failed ~repeats:true "start"
    (plan.checkpoint.checkpoint_id
   ^ " starts on a screen made by hand, which no reload reaches: put the \
      console there and run it again")

let back_to_autosave ~log ~picture =
  log "[Console] back to the latest autosave";
  Result.map_error
    (fun e -> failed ~repeats:true "reload" e)
    (Story.Game_reload.reload ~log ~picture)

(* Back to the latest autosave before a run that is not the series' first. *)
let start ~log ~picture ~reload (plan : P.Plan.t) =
  match (reload, plan.checkpoint.start) with
  | false, _ -> Ok ()
  | true, None -> Error (unreachable plan)
  | true, Some _ -> back_to_autosave ~log ~picture

(* 00.00-new-game's new game, with PLZA's HOME title uploaded for its launch; the
   choices it plays (the program's options over the plan's) in the log. *)
let new_game ~log ~picture choices =
  log ("[Console] new game: " ^ Story.New_game_options.describe choices);
  match Plza_checkpoint_series.Templates.upload_home_title () with
  | Error e -> Error (Engine_run.Failure.cause ~repeats:true "assets" e)
  | Ok home_title ->
      Story.Live_intro_screen.run ~picture ~log ~home_title choices

let run_checkpoint ~options ~log ~picture ~reload report (plan : P.Plan.t) =
  let* () = start ~log ~picture ~reload plan in
  let steps =
    Story.Live_story_screen.game_steps ~picture ~log ~log_detail:log
  in
  (* A console idle between runs dims its screen; nothing reads on it. *)
  Plza_story.Screen_wake.run steps;
  let id = plan.checkpoint.checkpoint_id in
  let* () =
    Result.map_error
      (Attempts.of_cause ~at:"start")
      (Story.Start_signature.check steps ~checkpoint_id:id plan.execution)
  in
  let game =
    Story.Story_game.make ~options steps ~checkpoint:plan.checkpoint
      ~new_game:(new_game ~log ~picture)
      ~reload:(reload_cause ~log ~picture)
  in
  let end_check () =
    Story.Start_signature.check_end steps ~checkpoint_id:id plan.execution
  in
  Result.map_error Attempts.of_failure
    (Story.Story_game.run_watched ~end_check ~mode:"testing" report game
       plan.checkpoint)

(* One attempt: the story's templates uploaded, its probes subscribed;
   [options] are 00.00-new-game's choices. *)
let attempt ~options ~log ~picture ~reload report plan : Attempts.outcome =
  match Plza_checkpoint_series.Templates.upload () with
  | Error e -> failed ~repeats:true "assets" e
  | Ok assets -> (
      match
        Effects.with_probes (Story.Live_story_screen.probes ~picture ~assets)
          (fun () -> run_checkpoint ~options ~log ~picture ~reload report plan)
      with
      | Ok () -> Passed
      | Error f -> f)

(* The story's runs, playing [new_game]'s choices at 00.00-new-game. *)
let story new_game : Series.program =
  {
    check_plans = Series_check.check_all ~options:new_game;
    daemon_flags = Series.keepawake_stick;
    attempt = attempt ~options:new_game;
  }

let run_series ~program ~options ~viewport plan_dir args =
  let* new_game = Story.New_game_options.of_run_options options in
  Series.run_series (story new_game) ~program_fields:program ~options ~viewport
    plan_dir args
