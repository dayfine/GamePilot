let plan ?(costs = Leg_costs.default) (model : _ Step_model.t) ~start
    ~start_facing ~at_goal ~goal_facing =
  let legs (found : _ Leg_search.found) =
    let walked = Leg.join ~held_at:model.held_at start found.moves in
    match goal_facing with
    | Some facing when found.end_facing <> Some facing ->
        walked @ [ Leg.face found.end_state facing ]
    | _ -> walked
  in
  Leg_search.run model costs ~start ~start_facing ~at_goal ~goal_facing
  |> Option.map legs
