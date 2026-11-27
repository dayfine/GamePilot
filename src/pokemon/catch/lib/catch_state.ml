type foe_status = Healthy | Asleep | Paralyzed | Other_status

let is_statused = function
  | Healthy -> false
  | Asleep | Paralyzed | Other_status -> true

type t = {
  turn : int;
  active_slot : int;
  active_hp_ratio : float option;
  foe_hp_ratio : float option;
  foe_status : foe_status option;
  balls_thrown : int;
  fainted : int list;
}

type role_config = { slot : int; move_slot : int; hp_floor : float }

type heavy_chipper_config = {
  slot : int;
  move_slot : int;
  hp_floor : float;
  foe_hp_floor : float;
  require_status : bool;
}

type false_swipe_config = {
  slot : int;
  move_slot : int;
  require_status : bool;
  hp_floor : float;
}

type wall_config = { slot : int; heal_move_slot : int option; hp_floor : float }

type policy = {
  status_setter : role_config option;
  heavy_chipper : heavy_chipper_config option;
  false_swiper : false_swipe_config option;
  wall : wall_config option;
  ball_name : string;
  max_balls : int;
  foe_hp_target : float;
  foe_hp_rechip : float;
  reapply_status : bool;
  max_turns : int;
  send_in_order : int list;
}

type command =
  | Use_move of int
  | Switch_to of int
  | Throw_ball of string
  | Heal_active
  | Pause_for_user of string

let describe_command = function
  | Use_move slot -> Printf.sprintf "use move %d" slot
  | Switch_to slot -> Printf.sprintf "switch to slot %d" slot
  | Throw_ball name -> Printf.sprintf "throw %s" name
  | Heal_active -> "heal active"
  | Pause_for_user reason -> Printf.sprintf "pause: %s" reason
