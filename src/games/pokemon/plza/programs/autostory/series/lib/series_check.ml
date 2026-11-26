module P = Plza_engine
module Story = Plza_autostory

let check ~options plans =
  Result.map
    (List.iter (fun c ->
         Printf.printf "[Checkpoints] the new game's choices: %s\n%!"
           (Story.New_game_options.describe c)))
    (Story.New_game_event.series_choices ~options
       (List.map (fun (p : P.Plan.t) -> p.checkpoint) plans))

let ( let* ) = Result.bind

let check_all ~options plans =
  let* () =
    Plza_checkpoint_series.Checkpoint_series.each_plan Story.Plan_check.check
      plans
  in
  check ~options plans
