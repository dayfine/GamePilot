type t = {
  turn : int;
  active_slot : int;
  active_hp_ratio : float;
  foe_hp_ratio : float;
  foe_asleep : bool;
  balls_thrown : int;
}

type role_config = { slot : int; move_slot : int; hp_floor : float }

type false_swipe_config = {
  slot : int;
  move_slot : int;
  require_sleep : bool;
  hp_floor : float;
}

type wall_config = { slot : int; heal_move_slot : int option; hp_floor : float }

type policy = {
  sleeper : role_config option;
  false_swiper : false_swipe_config option;
  wall : wall_config;
  ball_name : string;
  max_balls : int;
  foe_hp_target : float;
  foe_hp_rechip : float;
  reapply_sleep : bool;
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
