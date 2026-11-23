let plan ?costs game world rules ~start ~start_facing ~at_goal ~goal_facing =
  Leg_planner.plan ?costs
    (Gated_model.model game world rules)
    ~start ~start_facing
    ~at_goal:(fun (state : _ Gated_model.state) -> at_goal state.inner)
    ~goal_facing

let gate_change_of (leg : _ Gated_model.state Leg.t) =
  Gate_state.change_between ~before:leg.start.gates ~after:leg.finish.gates

let gates_after before legs =
  match List.rev legs with
  | [] -> before
  | (last : _ Gated_model.state Leg.t) :: _ -> last.finish.gates
