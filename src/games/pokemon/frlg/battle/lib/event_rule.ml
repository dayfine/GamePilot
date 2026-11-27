type state = {
  seen_battle : bool;
  leveled_up : bool;
  last_press_ms : float;
  no_battle_since_ms : float option;
}

let resume ~seen_battle ~leveled_up ~at_ms =
  { seen_battle; leveled_up; last_press_ms = at_ms; no_battle_since_ms = None }

let start ~at_ms = resume ~seen_battle:false ~leveled_up:false ~at_ms
let seen_battle s = s.seen_battle
let leveled_up s = s.leveled_up

type step = Report of Battle.event | Press of Wire.button | Look

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
        (state, Report Battle.Battle_over)
    | Some _ -> (state, Look)

let next state (facts : Battle_look.facts) ~at_ms =
  let screen = Battle_look.classify facts in
  let seen = { state with seen_battle = true; no_battle_since_ms = None } in
  match screen with
  | No_battle -> no_battle state ~at_ms
  | Action_menu -> (seen, Report Battle.Action_menu)
  | Party_list -> (seen, Report Battle.Switch_in)
  | Yes_no ->
      let event =
        if facts.move_learn then Battle.Move_learn else Battle.Use_next
      in
      (seen, Report event)
  | Level_up -> ({ seen with leveled_up = true }, Report Battle.Level_up)
  | Move_menu | Bag -> press_held seen Wire.B ~at_ms
  | Text_arrow -> press_held ~gap_ms:arrow_press_gap_ms seen Wire.B ~at_ms
  | Evolution when state.leveled_up -> (seen, Report Battle.Evolution)
  | Evolution -> press_held ~gap_ms:stuck_text_ms seen Wire.B ~at_ms
  | Battle_text -> press_held ~gap_ms:stuck_text_ms seen Wire.B ~at_ms
