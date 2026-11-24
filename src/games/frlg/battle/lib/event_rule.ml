type state = {
  seen_battle : bool;
  leveled_up : bool;
  last_press_ms : float;
  no_battle_since_ms : float option;
}

let start ~at_ms =
  {
    seen_battle = false;
    leveled_up = false;
    last_press_ms = at_ms;
    no_battle_since_ms = None;
  }

type step = Report of Battle_driver.event | Press of Wire.button | Look

let arrow_press_gap_ms = 500.
let press_gap_ms = 1500.
let stuck_text_ms = 6000.
let over_after_ms = 3000.

(* A press once the screen has held [gap_ms] since the last one. *)
let press_held ?(gap_ms = press_gap_ms) state button ~at_ms =
  if at_ms -. state.last_press_ms >= gap_ms then
    ({ state with last_press_ms = at_ms }, Press button)
  else (state, Look)

let no_battle state ~at_ms =
  if not state.seen_battle then (state, Look)
  else
    match state.no_battle_since_ms with
    | None -> ({ state with no_battle_since_ms = Some at_ms }, Look)
    | Some since when at_ms -. since >= over_after_ms ->
        (state, Report Battle_driver.Battle_over)
    | Some _ -> (state, Look)

let next state (facts : Battle_look.facts) ~at_ms =
  let screen = Battle_look.classify facts in
  let seen = { state with seen_battle = true; no_battle_since_ms = None } in
  match screen with
  | No_battle -> no_battle state ~at_ms
  | Action_menu -> (seen, Report Battle_driver.Action_menu)
  | Party_list -> (seen, Report Battle_driver.Switch_in)
  | Yes_no ->
      let event =
        if facts.move_learn then Battle_driver.Move_learn
        else Battle_driver.Use_next
      in
      (seen, Report event)
  | Level_up -> press_held { seen with leveled_up = true } Wire.A ~at_ms
  | Move_menu | Bag -> press_held seen Wire.B ~at_ms
  | Text_arrow -> press_held ~gap_ms:arrow_press_gap_ms seen Wire.B ~at_ms
  | Evolution when state.leveled_up -> (seen, Look)
  | Evolution -> press_held ~gap_ms:stuck_text_ms seen Wire.B ~at_ms
  | Battle_text -> press_held ~gap_ms:stuck_text_ms seen Wire.B ~at_ms
