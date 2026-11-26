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

let load_checked load ~options ids =
  let* plans =
    List.fold_left
      (fun plans id ->
        let* plans = plans in
        let* plan = load id in
        let* () = Story.Plan_check.check plan in
        Ok (plans @ [ plan ]))
      (Ok []) ids
  in
  let* () = check ~options plans in
  Ok plans
