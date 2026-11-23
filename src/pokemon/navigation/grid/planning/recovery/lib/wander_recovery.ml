type policy = { max_waits : int; wait_ms : int; probe_with_a : bool }
type state = { waits_used : int }

let fresh = { waits_used = 0 }

type wall_stop = { touches_wander_zone : bool; probed_person : bool }
type wall_action = Wait_and_rehold | Replan_before_zone
type mid_leg_stop = { wanderer_ahead : bool; can_resume_remaining : bool }
type mid_leg_action = Wait_and_resume_remaining | Wait_and_reanchor
type unmoved_action = Wait_and_retry

(* The state after one more wait, if one is left. *)
let spend_wait policy state =
  if state.waits_used < policy.max_waits then
    Some { waits_used = state.waits_used + 1 }
  else None

(* [action] after spending a wait, or [exhausted] with the state unchanged. *)
let wait_then policy state action ~exhausted =
  match spend_wait policy state with
  | Some spent -> (Some action, spent)
  | None -> (exhausted, state)

let decide_wall policy state stop =
  if
    (not stop.touches_wander_zone)
    || (policy.probe_with_a && not stop.probed_person)
  then (None, state)
  else
    let exhausted =
      if policy.probe_with_a then Some Replan_before_zone else None
    in
    wait_then policy state Wait_and_rehold ~exhausted

let decide_mid_leg policy state stop =
  if not stop.wanderer_ahead then (None, state)
  else
    let action =
      if stop.can_resume_remaining then Wait_and_resume_remaining
      else Wait_and_reanchor
    in
    wait_then policy state action ~exhausted:None

let decide_unmoved policy state ~blocked_by_wanderer =
  if not blocked_by_wanderer then (None, state)
  else wait_then policy state Wait_and_retry ~exhausted:None
