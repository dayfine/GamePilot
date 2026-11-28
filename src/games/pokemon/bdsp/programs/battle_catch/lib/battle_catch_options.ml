module CS = Pokemon_catch.Catch_state
module BCS = Bdsp_actions.Battle_catch_steps

type t = {
  target : string;
  lead_slot : int;
  bag : BCS.bag_layout;
  fallback_ball_steps : int;
  policy : CS.policy;
}

type limits = {
  max_slot : int;
  max_move : int;
  floor_min_pct : int;
  floor_max_pct : int;
  default_floor_pct : int;
  default_max_balls : int;
  max_balls : int;
  min_turns : int;
  default_max_turns : int;
  max_turns : int;
  pocket_bound : int;
  max_row : int;
  default_sleep_move : int;
  default_fs_move : int;
  default_wall_slot : int;
}

let lim =
  {
    max_slot = 6;
    max_move = 4;
    floor_min_pct = 15;
    floor_max_pct = 80;
    default_floor_pct = 30;
    default_max_balls = 60;
    max_balls = 99;
    min_turns = 10;
    default_max_turns = 80;
    max_turns = 200;
    pocket_bound = 5;
    max_row = 20;
    default_sleep_move = 3;
    default_fs_move = 2;
    default_wall_slot = 6;
  }

let status_hp = 0.55
let chipper_hp = 0.45
let swiper_hp = 0.55
let wall_hp = 0.55
let foe_target = 0.15
let foe_rechip = 0.35
let pct_divisor = 100.0

let ball_display_name = function
  | "luxury" -> Ok "Luxury Ball"
  | "ultra" -> Ok "Ultra Ball"
  | "timer" -> Ok "Timer Ball"
  | "dusk" -> Ok "Dusk Ball"
  | "premier" -> Ok "Premier Ball"
  | "master" -> Ok "Master Ball"
  | other -> Error (Printf.sprintf "unknown ball %S" other)

let int_opt ~key ~default ~min ~max opts =
  let v = Option.value ~default (Run_options.int opts key) in
  if v < min || v > max then
    Error (Printf.sprintf "%s=%d out of range [%d..%d]" key v min max)
  else Ok v

let dedup_slots slots =
  let rec loop seen acc = function
    | [] -> List.rev acc
    | s :: rest ->
        if s <= 0 || List.mem s seen then loop seen acc rest
        else loop (s :: seen) (s :: acc) rest
  in
  loop [] [] slots

let ( let* ) = Result.bind

type raw_slots = {
  lead_slot : int;
  sleep_slot : int;
  sleep_move : int;
  false_swipe_slot : int;
  false_swipe_move : int;
  setup_slot : int;
  setup_move : int;
  setup_uses : int;
  chipper_slot : int;
  chipper_move : int;
  chipper_floor_pct : int;
  wall_slot : int;
  wall_heal_move : int;
}

let parse_slots opts =
  let slot_opt key default =
    int_opt ~key ~default ~min:0 ~max:lim.max_slot opts
  in
  let move_opt key default =
    int_opt ~key ~default ~min:1 ~max:lim.max_move opts
  in
  let* lead_slot =
    int_opt ~key:"lead_slot" ~default:1 ~min:1 ~max:lim.max_slot opts
  in
  let* sleep_slot = slot_opt "sleep_slot" 1 in
  let* sleep_move = move_opt "sleep_move" lim.default_sleep_move in
  let* false_swipe_slot = slot_opt "false_swipe_slot" 1 in
  let* false_swipe_move = move_opt "false_swipe_move" lim.default_fs_move in
  let* setup_slot = slot_opt "setup_slot" 0 in
  let* setup_move = move_opt "setup_move" lim.max_move in
  let* setup_uses =
    int_opt ~key:"setup_uses" ~default:2 ~min:1 ~max:lim.max_slot opts
  in
  let* chipper_slot = slot_opt "chipper_slot" 0 in
  let* chipper_move = move_opt "chipper_move" 1 in
  let* chipper_floor_pct =
    int_opt ~key:"chipper_floor_pct" ~default:lim.default_floor_pct
      ~min:lim.floor_min_pct ~max:lim.floor_max_pct opts
  in
  let* wall_slot = slot_opt "wall_slot" lim.default_wall_slot in
  let* wall_heal_move =
    int_opt ~key:"wall_heal_move" ~default:0 ~min:0 ~max:lim.max_move opts
  in
  Ok
    {
      lead_slot;
      sleep_slot;
      sleep_move;
      false_swipe_slot;
      false_swipe_move;
      setup_slot;
      setup_move;
      setup_uses;
      chipper_slot;
      chipper_move;
      chipper_floor_pct;
      wall_slot;
      wall_heal_move;
    }

let parse_bag opts =
  let* ball_pocket_steps =
    int_opt ~key:"ball_pocket_steps" ~default:0 ~min:(-lim.pocket_bound)
      ~max:lim.pocket_bound opts
  in
  let* ball_row =
    int_opt ~key:"ball_row" ~default:(-1) ~min:(-lim.max_row) ~max:lim.max_row
      opts
  in
  let* heal_pocket_steps =
    int_opt ~key:"heal_pocket_steps" ~default:0 ~min:(-lim.pocket_bound)
      ~max:lim.pocket_bound opts
  in
  let* heal_row =
    int_opt ~key:"heal_row" ~default:0 ~min:0 ~max:lim.max_row opts
  in
  Ok { BCS.ball_pocket_steps; ball_row; heal_pocket_steps; heal_row }

let make_status_setter s =
  if s.sleep_slot = 0 then None
  else
    Some
      { CS.slot = s.sleep_slot; move_slot = s.sleep_move; hp_floor = status_hp }

let make_setup s =
  if s.setup_slot = 0 then None
  else
    Some
      {
        CS.slot = s.setup_slot;
        move_slot = s.setup_move;
        uses = s.setup_uses;
        require_status = s.sleep_slot > 0;
      }

let make_heavy_chipper s =
  if s.chipper_slot = 0 then None
  else
    let foe_hp_floor = float_of_int s.chipper_floor_pct /. pct_divisor in
    Some
      {
        CS.slot = s.chipper_slot;
        move_slot = s.chipper_move;
        hp_floor = chipper_hp;
        foe_hp_floor;
        require_status = s.sleep_slot > 0;
      }

let make_false_swiper s =
  if s.false_swipe_slot = 0 then None
  else
    Some
      {
        CS.slot = s.false_swipe_slot;
        move_slot = s.false_swipe_move;
        require_status = s.sleep_slot > 0;
        hp_floor = swiper_hp;
      }

let make_wall s =
  if s.wall_slot = 0 then None
  else
    let heal_move_slot =
      if s.wall_heal_move = 0 then None else Some s.wall_heal_move
    in
    Some { CS.slot = s.wall_slot; heal_move_slot; hp_floor = wall_hp }

let build_policy ~ball_name ~fallback_ball ~max_balls ~max_turns s : CS.policy =
  let all_slots = List.init lim.max_slot (fun i -> i + 1) in
  let send_in_order =
    dedup_slots
      ([ s.wall_slot; s.sleep_slot; s.false_swipe_slot; s.chipper_slot ]
      @ all_slots)
  in
  {
    CS.status_setter = make_status_setter s;
    setup = make_setup s;
    heavy_chipper = make_heavy_chipper s;
    false_swiper = make_false_swiper s;
    wall = make_wall s;
    ball_name;
    fallback_ball;
    max_balls;
    foe_hp_target = foe_target;
    foe_hp_rechip = foe_rechip;
    reapply_status = s.sleep_slot > 0;
    max_turns;
    send_in_order;
  }

let default_fallback_turn = 25
let default_fallback_steps = -6

let parse_fallback opts =
  let key =
    Option.value ~default:"none" (Run_options.find opts "fallback_ball")
  in
  let* steps =
    int_opt ~key:"fallback_ball_steps" ~default:default_fallback_steps
      ~min:(-lim.max_row) ~max:lim.max_row opts
  in
  if key = "none" then Ok (None, steps)
  else
    let* name = ball_display_name key in
    let* turn =
      int_opt ~key:"fallback_turn" ~default:default_fallback_turn ~min:1
        ~max:lim.max_turns opts
    in
    Ok (Some (turn, name), steps)

let of_run_options opts =
  let target =
    Option.value ~default:"groudon" (Run_options.find opts "target")
  in
  let ball_key =
    Option.value ~default:"luxury" (Run_options.find opts "ball")
  in
  let* ball_name = ball_display_name ball_key in
  let* fallback_ball, fallback_ball_steps = parse_fallback opts in
  let* max_balls =
    int_opt ~key:"max_balls" ~default:lim.default_max_balls ~min:1
      ~max:lim.max_balls opts
  in
  let* max_turns =
    int_opt ~key:"max_turns" ~default:lim.default_max_turns ~min:lim.min_turns
      ~max:lim.max_turns opts
  in
  let* slots = parse_slots opts in
  let* bag = parse_bag opts in
  let policy =
    build_policy ~ball_name ~fallback_ball ~max_balls ~max_turns slots
  in
  Ok { target; lead_slot = slots.lead_slot; bag; fallback_ball_steps; policy }

let format_summary cfg =
  let chip_text =
    match cfg.policy.heavy_chipper with
    | None -> "none"
    | Some hc ->
        Printf.sprintf "slot%d/m%d(floor=%.0f%%)" hc.slot hc.move_slot
          (hc.foe_hp_floor *. pct_divisor)
  in
  Printf.sprintf "target=%s ball=%s lead=%d chipper=%s max_balls=%d" cfg.target
    cfg.policy.ball_name cfg.lead_slot chip_text cfg.policy.max_balls
