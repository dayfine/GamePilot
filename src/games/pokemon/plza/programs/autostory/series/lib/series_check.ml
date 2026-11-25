module P = Plza_engine
module Story = Plza_autostory

let ( let* ) = Result.bind

let all_ok results =
  List.fold_right
    (fun r acc -> Result.bind r (fun x -> Result.map (List.cons x) acc))
    results (Ok [])

let check ~options plans =
  let* (_ : unit list) = all_ok (List.map Story.Plan_check.check plans) in
  let* choices =
    Story.New_game_event.series_choices ~options
      (List.map (fun (p : P.Plan.t) -> p.checkpoint) plans)
  in
  List.iter
    (fun c ->
      Printf.printf "[Checkpoints] the new game's choices: %s\n%!"
        (Story.New_game_options.describe c))
    choices;
  Ok ()
