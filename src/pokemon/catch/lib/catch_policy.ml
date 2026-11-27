open Catch_state

let is_fainted state slot = List.mem slot state.fainted

let active_hp_floor policy active_slot =
  match (policy.status_setter, policy.false_swiper, policy.wall) with
  | Some ss, _, _ when ss.slot = active_slot -> ss.hp_floor
  | _, Some fs, _ when fs.slot = active_slot -> fs.hp_floor
  | _, _, Some w when w.slot = active_slot -> w.hp_floor
  | _ -> 0.0

let use_or_switch ~active_slot ~target_slot ~move_slot =
  if active_slot = target_slot then Use_move move_slot
  else Switch_to target_slot

let needs_status state =
  match state.foe_status with
  | Some status -> not (is_statused status)
  | None -> false

let survival_for_wall policy state =
  match policy.wall with
  | Some w when state.active_slot = w.slot -> (
      match w.heal_move_slot with
      | Some m -> Some (Use_move m)
      | None -> Some Heal_active)
  | Some w when not (is_fainted state w.slot) -> Some (Switch_to w.slot)
  | Some _ | None -> Some Heal_active

let survival_command policy state =
  match state.active_hp_ratio with
  | None -> None
  | Some ratio ->
      let floor = active_hp_floor policy state.active_slot in
      if ratio >= floor then None else survival_for_wall policy state

let status_or_pause policy state =
  match policy.status_setter with
  | Some ss when not (is_fainted state ss.slot) ->
      Some
        (use_or_switch ~active_slot:state.active_slot ~target_slot:ss.slot
           ~move_slot:ss.move_slot)
  | Some _ | None -> Some (Pause_for_user "need status before false swipe")

let chip_for_swiper policy state (fs : false_swipe_config) =
  if is_fainted state fs.slot then None
  else if fs.require_status && needs_status state then
    status_or_pause policy state
  else
    Some
      (use_or_switch ~active_slot:state.active_slot ~target_slot:fs.slot
         ~move_slot:fs.move_slot)

let chip_command policy state =
  match state.foe_hp_ratio with
  | None -> None
  | Some ratio ->
      let threshold =
        if state.balls_thrown > 0 then policy.foe_hp_rechip
        else policy.foe_hp_target
      in
      if ratio <= threshold then None
      else Option.bind policy.false_swiper (chip_for_swiper policy state)

let status_command policy state =
  match policy.status_setter with
  | Some ss
    when policy.reapply_status && needs_status state
         && not (is_fainted state ss.slot) ->
      Some
        (use_or_switch ~active_slot:state.active_slot ~target_slot:ss.slot
           ~move_slot:ss.move_slot)
  | _ -> None

let ball_command policy state =
  match (policy.false_swiper, policy.wall) with
  | Some fs, Some w
    when fs.require_status
         && state.active_slot = fs.slot
         && not (is_fainted state w.slot) ->
      Switch_to w.slot
  | _ -> Throw_ball policy.ball_name

let limit_command policy state =
  if state.turn >= policy.max_turns then
    Some
      (Pause_for_user
         (Printf.sprintf "turn limit reached (%d)" policy.max_turns))
  else if state.balls_thrown >= policy.max_balls then
    Some
      (Pause_for_user
         (Printf.sprintf "ball limit reached (%d)" policy.max_balls))
  else None

let first_some xs ~default =
  match List.find_map Fun.id xs with Some v -> v | None -> default

let decide policy state =
  first_some
    [
      limit_command policy state;
      survival_command policy state;
      chip_command policy state;
      status_command policy state;
    ]
    ~default:(ball_command policy state)

let next_send_in policy ~fainted =
  List.find_opt (fun slot -> not (List.mem slot fainted)) policy.send_in_order
