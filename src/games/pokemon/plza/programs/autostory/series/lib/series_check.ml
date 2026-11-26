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

(* The starter 01.04 walks to, when given. *)
let check_starter starter plans =
  let* () =
    Story.Starter_option.series_check starter
      (List.map (fun (p : P.Plan.t) -> p.checkpoint) plans)
  in
  Option.iter
    (fun s ->
      Printf.printf "[Checkpoints] the starter: %s (%s)\n%!"
        (Plza_story.Starter.name s)
        (Plza_story.Starter.tag s))
    starter;
  Ok ()

let check_all ~options ~starter plans =
  let* () =
    Plza_checkpoint_series.Checkpoint_series.each_plan Story.Plan_check.check
      plans
  in
  let* () = check ~options plans in
  check_starter starter plans
