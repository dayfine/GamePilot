type 'state t = {
  compare_state : 'state -> 'state -> int;
  step : 'state -> Direction.t -> 'state option;
  step_tiles : 'state -> 'state -> int;
  held_at : 'state -> Direction.t -> bool;
  wild : 'state -> bool;
  wander : 'state -> bool;
}

let nowhere _ = false
let one_tile _ _ = 1

(* A warp or a game action: the player stops without being held. *)
let leaves (step : _ Grid_planning.Leg.step) =
  Option.is_some step.special_step || step.warped

let of_step_model ?(wild = nowhere) ?(wander = nowhere) ?(step_tiles = one_tile)
    (model : _ Grid_planning.Step_model.t) =
  let step state direction =
    match model.press state direction with
    | Some s when not (leaves s) -> Some s.next
    | Some _ | None -> None
  in
  let held_at state direction =
    match model.press state direction with
    | Some s when leaves s -> false
    | Some _ | None -> model.held_at state direction
  in
  {
    compare_state = model.compare_state;
    step;
    step_tiles;
    held_at;
    wild;
    wander;
  }
