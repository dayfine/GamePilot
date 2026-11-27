open Catch_state

let active_hp_floor policy active_slot =
  match (policy.sleeper, policy.false_swiper) with
  | Some sl, _ when sl.slot = active_slot -> sl.hp_floor
  | _, Some fs when fs.slot = active_slot -> fs.hp_floor
  | _ -> policy.wall.hp_floor

let use_or_switch ~active_slot ~target_slot ~move_slot =
  if active_slot = target_slot then Use_move move_slot
  else Switch_to target_slot

let survival_command policy state =
  let floor = active_hp_floor policy state.active_slot in
  if state.active_hp_ratio >= floor then None
  else if state.active_slot = policy.wall.slot then
    match policy.wall.heal_move_slot with
    | Some m -> Some (Use_move m)
    | None -> Some Heal_active
  else Some (Switch_to policy.wall.slot)

let sleep_or_pause policy state =
  match policy.sleeper with
  | Some sl ->
      Some
        (use_or_switch ~active_slot:state.active_slot ~target_slot:sl.slot
           ~move_slot:sl.move_slot)
  | None -> Some (Pause_for_user "need sleep before false swipe")

let chip_for_swiper policy state (fs : false_swipe_config) =
  if fs.require_sleep && not state.foe_asleep then sleep_or_pause policy state
  else
    Some
      (use_or_switch ~active_slot:state.active_slot ~target_slot:fs.slot
         ~move_slot:fs.move_slot)

let chip_command policy state =
  let threshold =
    if state.balls_thrown > 0 then policy.foe_hp_rechip
    else policy.foe_hp_target
  in
  if state.foe_hp_ratio <= threshold then None
  else Option.bind policy.false_swiper (chip_for_swiper policy state)

let sleep_command policy state =
  match policy.sleeper with
  | Some sl when policy.reapply_sleep && not state.foe_asleep ->
      Some
        (use_or_switch ~active_slot:state.active_slot ~target_slot:sl.slot
           ~move_slot:sl.move_slot)
  | _ -> None

let ball_command policy state =
  match policy.false_swiper with
  | Some fs when fs.require_sleep && state.active_slot = fs.slot ->
      Switch_to policy.wall.slot
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
      sleep_command policy state;
    ]
    ~default:(ball_command policy state)

let next_send_in policy ~fainted =
  List.find_opt (fun slot -> not (List.mem slot fainted)) policy.send_in_order
