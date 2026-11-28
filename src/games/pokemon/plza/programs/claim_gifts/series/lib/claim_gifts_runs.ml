module P = Plza_engine
module Series = Plza_checkpoint_series.Checkpoint_series
module Attempts = Plza_checkpoint_series.Run_attempts
module Gift_inputs = Plza_checkpoint_series.Gift_inputs

let ( let* ) = Result.bind
let default_language = "en"

type inputs = {
  catalog : Plza_gift_catalog.Gift_catalog.t;
  today : Plza_gift_catalog.Gift_catalog.date;
  name_templates : (string * string) list;
}

let load_inputs options =
  let* catalog = Gift_inputs.catalog () in
  let language =
    Option.value ~default:default_language (Run_options.find options "language")
  in
  Ok
    {
      catalog;
      today = Gift_inputs.today ();
      name_templates =
        Gift_inputs.name_templates
          ~template_path:Plza_claim_gifts.Live_gift_steps.name_template
          ~language catalog;
    }

let guide_blocks = [ ("gifts", Gift_inputs.gifts_block) ]

let run_checkpoint inputs ~log ~picture ~assets report (plan : P.Plan.t) =
  let game =
    Plza_claim_gifts.Live_gift_steps.game ~catalog:inputs.catalog
      ~today:inputs.today ~name_templates:inputs.name_templates ~log ~picture
      ~assets
  in
  (* A console idle before the run dims its screen; nothing reads on it. *)
  Switch.Stick_wake.run ();
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

let initial_screen _ : Switch.Initial_screen.expectation =
  In_game_or_resume (Some Plza_readers.Switch_home_tile.tile_color)

let run_series ~program ~options ~viewport plan_dir args =
  let* inputs = load_inputs options in
  Series.run_series
    {
      check_plans = Series.each_plan Plza_claim_gifts.Claim_gifts.check_plan;
      with_end_place = Series.no_end_place;
      daemon_flags = Series.keepawake_stick;
      initial_screen;
      attempt = attempt inputs;
    }
    ~program_fields:program ~options ~viewport plan_dir args
