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

(* The plan's end place: its own, or the next checkpoint's start signature,
   put in its postconditions as the series loaded it (with_end_place). *)
let ends (plan : P.Plan.t) =
  Option.value plan.postconditions
    ~default:{ Plza_rules.Postconditions.place = None; flags = [] }

let with_end_place ~next plan =
  Result.map_error Engine_run.Failure.cause_to_string
    (Result.map
       (fun ends -> { plan with P.Plan.postconditions = Some ends })
       (Story.Start_signature.promised_end ~next plan))

let end_state steps ~checkpoint_id (plan : P.Plan.t) =
  (ends plan, Story.Start_signature.read_end steps ~checkpoint_id)

let run_checkpoint ~options ~starter ~log ~picture ~reload report
    (plan : P.Plan.t) =
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
      (Story.Start_signature.check steps ~checkpoint_id:id
         ~at_end:(ends plan).place plan.execution)
  in
  let game =
    Story.Story_game.make ~options ~starter steps ~checkpoint:plan.checkpoint
      ~new_game:(new_game ~log ~picture)
      ~reload:(reload_cause ~log ~picture)
  in
  Result.map_error Attempts.of_failure
    (Story.Story_game.run_watched
       ~end_state:(end_state steps ~checkpoint_id:id plan)
       ~mode:"testing" report game plan.checkpoint)

(* One attempt: the story's templates uploaded, its probes subscribed;
   [options] are 00.00-new-game's choices, [starter] the one 01.04 walks to. *)
let attempt ~options ~starter ~log ~picture ~reload report plan :
    Attempts.outcome =
  let run () =
    run_checkpoint ~options ~starter ~log ~picture ~reload report plan
  in
  match Plza_checkpoint_series.Templates.upload () with
  | Error e -> failed ~repeats:true "assets" e
  | Ok assets -> (
      match
        Effects.with_probes
          (Story.Live_story_screen.probes ~picture ~assets)
          run
      with
      | Ok () -> Passed
      | Error f -> f)

let initial_screen (plan : P.Plan.t) : Switch.Initial_screen.expectation =
  match plan.checkpoint.start with
  | None -> In_game_or_home
  | Some _ -> In_game_or_resume (Some Plza_readers.Switch_home_tile.tile_color)

(* The story's runs, playing [new_game]'s choices at 00.00-new-game and
   walking to [starter] in 01.04 (Chikorita when not given). *)
let story new_game starter : Series.program =
  {
    check_plans = Series_check.check_all ~options:new_game ~starter;
    with_end_place;
    daemon_flags = Series.keepawake_stick;
    initial_screen;
    attempt =
      attempt ~options:new_game
        ~starter:(Option.value starter ~default:Plza_story.Starter.default);
  }

let run_series ~program ~options ~viewport plan_dir args =
  let* new_game = Story.New_game_options.of_run_options options in
  let* starter = Story.Starter_option.of_run_options options in
  Series.run_series (story new_game starter) ~program_fields:program ~options
    ~viewport plan_dir args
