module B = Switch.Black_screen
module H = Screen_graph.Held_screen
module P = Switch.Switch_presses
module Hud = Bdsp_readers.Battle_hud
module CS = Pokemon_catch.Catch_state
module CR = Pokemon_catch.Catch_runner

type bag_layout = {
  ball_pocket_steps : int;
  ball_row : int;
  heal_pocket_steps : int;
  heal_row : int;
}

type timing = {
  press_hold_ms : int;
  press_cooldown_ms : int;
  nav_cooldown_ms : int;
  menu_settle_ms : int;
  event_timeout_ms : int;
  dialog_advance_ms : int;
  black_hold_ms : float;
}

type config = {
  picture : Wire.box;
  initial_active_slot : int;
  bag : bag_layout;
  timing : timing;
}

type party_slots = {
  status_setter : int;
  status_move : int;
  false_swiper : int;
  false_swipe_move : int;
  wall : int;
  wall_heal_move : int option;
  send_in_order : int list;
}

type policy_defaults = {
  ball_name : string;
  max_balls : int;
  max_turns : int;
  status_floor : float;
  swiper_floor : float;
  wall_floor : float;
  foe_target : float;
  kyogre_rechip : float;
}

type groudon_extra = { groudon_rechip : float; poll_slice_ms : int }

let defaults : policy_defaults =
  {
    ball_name = "Luxury Ball";
    max_balls = 60;
    max_turns = 80;
    status_floor = 0.35;
    swiper_floor = 0.40;
    wall_floor = 0.45;
    foe_target = 0.15;
    kyogre_rechip = 0.35;
  }

let extra : groudon_extra = { groudon_rechip = 0.40; poll_slice_ms = 500 }

let default_timing : timing =
  {
    press_hold_ms = 80;
    press_cooldown_ms = 240;
    nav_cooldown_ms = 180;
    menu_settle_ms = 450;
    event_timeout_ms = 30_000;
    dialog_advance_ms = 350;
    black_hold_ms = 200.;
  }

let tap t btn =
  P.press ~hold_ms:t.press_hold_ms ~cooldown_ms:t.press_cooldown_ms btn

let nav_repeat t btn count =
  for _ = 1 to max 0 count do
    P.press ~hold_ms:t.press_hold_ms ~cooldown_ms:t.nav_cooldown_ms btn
  done

let move_pockets t steps =
  if steps > 0 then nav_repeat t Wire.Right steps
  else if steps < 0 then nav_repeat t Wire.Left (-steps)

let select_party_slot t slot =
  nav_repeat t Wire.Down (slot - 1);
  tap t Wire.A;
  tap t Wire.A

type tracker = {
  mutable subscribed : bool;
  mutable active_slot : int;
  mutable turns : int;
  mutable balls_thrown : int;
}

let ensure_probes cfg tr =
  if not tr.subscribed then (
    ignore
      (Effects.subscribe (Hud.all_battle_probes ~picture:cfg.picture)
        : string list);
    tr.subscribed <- true)

let read_foe_status m =
  Option.map
    (fun asleep -> if asleep then CS.Asleep else CS.Healthy)
    (Hud.foe_asleep m)

let read_action_state tr m : CS.t =
  {
    turn = tr.turns;
    active_slot = tr.active_slot;
    active_hp_ratio = Hud.player_hp_ratio m;
    foe_hp_ratio = Hud.foe_hp_ratio m;
    foe_status = read_foe_status m;
    balls_thrown = tr.balls_thrown;
    fainted = [];
  }

let is_not_black m = if not (B.shown m) then Some () else None

let wait_battle_end ~log cfg tr =
  let t = cfg.timing in
  if tr.balls_thrown > 0 then (
    log "Battle faded to black after ball throw; waiting for fade clear...";
    ignore
      (H.wait_for ~timeout_ms:t.event_timeout_ms
         (H.held t.black_hold_ms is_not_black));
    Ok (CR.Caught : CR.event))
  else Ok (CR.Unexpected "black screen before any ball was thrown")

let inspect_frame ~log cfg tr m =
  let t = cfg.timing in
  match Hud.classify_screen m with
  | Hud.Action_menu -> Some (Ok (CR.Action_menu (read_action_state tr m)))
  | Hud.Forced_switch ->
      Some (Ok (CR.Forced_switch { fainted_slot = tr.active_slot }))
  | Hud.Dialog ->
      P.press ~hold_ms:t.press_hold_ms ~cooldown_ms:t.dialog_advance_ms Wire.A;
      None
  | Hud.Black -> Some (wait_battle_end ~log cfg tr)
  | Hud.Other -> None

let rec poll_event ~log cfg tr deadline =
  let remaining = int_of_float (deadline -. Effects.now ()) in
  if remaining <= 0 then
    Ok (CR.Unexpected "timed out waiting for BDSP battle event")
  else
    let slice = min remaining extra.poll_slice_ms in
    match Effects.await ~timeout_ms:slice (fun _ -> true) with
    | Effects.Timeout -> poll_event ~log cfg tr deadline
    | Effects.Holds m -> (
        match inspect_frame ~log cfg tr m with
        | Some res -> res
        | None -> poll_event ~log cfg tr deadline)

let next_event ~log cfg tr () =
  ensure_probes cfg tr;
  let deadline = Effects.now () +. float_of_int cfg.timing.event_timeout_ms in
  poll_event ~log cfg tr deadline

let execute_command ~log cfg tr = function
  | CS.Use_move move_slot ->
      let t = cfg.timing in
      log (Printf.sprintf "BDSP: Fight -> move %d" move_slot);
      tap t Wire.A;
      P.wait t.menu_settle_ms;
      nav_repeat t Wire.Down (move_slot - 1);
      tap t Wire.A;
      tr.turns <- tr.turns + 1;
      Ok ()
  | CS.Switch_to slot ->
      let t = cfg.timing in
      log (Printf.sprintf "BDSP: Pokémon -> slot %d" slot);
      nav_repeat t Wire.Down 1;
      tap t Wire.A;
      P.wait t.menu_settle_ms;
      select_party_slot t slot;
      tr.active_slot <- slot;
      tr.turns <- tr.turns + 1;
      Ok ()
  | CS.Throw_ball name ->
      let t = cfg.timing in
      log ("BDSP: Bag -> throw " ^ name);
      nav_repeat t Wire.Down 2;
      tap t Wire.A;
      P.wait t.menu_settle_ms;
      move_pockets t cfg.bag.ball_pocket_steps;
      nav_repeat t Wire.Down cfg.bag.ball_row;
      tap t Wire.A;
      tap t Wire.A;
      tr.balls_thrown <- tr.balls_thrown + 1;
      tr.turns <- tr.turns + 1;
      Ok ()
  | CS.Heal_active ->
      let t = cfg.timing in
      log (Printf.sprintf "BDSP: Bag -> heal slot %d" tr.active_slot);
      nav_repeat t Wire.Down 2;
      tap t Wire.A;
      P.wait t.menu_settle_ms;
      move_pockets t cfg.bag.heal_pocket_steps;
      nav_repeat t Wire.Down cfg.bag.heal_row;
      tap t Wire.A;
      tap t Wire.A;
      nav_repeat t Wire.Down (tr.active_slot - 1);
      tap t Wire.A;
      tr.turns <- tr.turns + 1;
      Ok ()
  | CS.Pause_for_user _ -> Ok ()

let send_in ~log cfg tr slot =
  let t = cfg.timing in
  log (Printf.sprintf "BDSP: forced switch -> slot %d" slot);
  P.wait t.menu_settle_ms;
  select_party_slot t slot;
  tr.active_slot <- slot;
  Ok ()

let make ?(log = ignore) cfg : CR.game_steps =
  let tr =
    {
      subscribed = false;
      active_slot = cfg.initial_active_slot;
      turns = 0;
      balls_thrown = 0;
    }
  in
  {
    next_event = next_event ~log cfg tr;
    execute = execute_command ~log cfg tr;
    send_in = send_in ~log cfg tr;
  }

let build_policy ~ball_name ~max_balls ~max_turns ~foe_hp_rechip ~heavy_chipper
    (slots : party_slots) : CS.policy =
  let status_setter : CS.role_config =
    {
      slot = slots.status_setter;
      move_slot = slots.status_move;
      hp_floor = defaults.status_floor;
    }
  in
  let false_swiper : CS.false_swipe_config =
    {
      slot = slots.false_swiper;
      move_slot = slots.false_swipe_move;
      require_status = true;
      hp_floor = defaults.swiper_floor;
    }
  in
  let wall : CS.wall_config =
    {
      slot = slots.wall;
      heal_move_slot = slots.wall_heal_move;
      hp_floor = defaults.wall_floor;
    }
  in
  {
    status_setter = Some status_setter;
    heavy_chipper;
    false_swiper = Some false_swiper;
    wall = Some wall;
    ball_name;
    max_balls;
    foe_hp_target = defaults.foe_target;
    foe_hp_rechip;
    reapply_status = true;
    max_turns;
    send_in_order = slots.send_in_order;
  }

let kyogre_policy ?(ball_name = defaults.ball_name)
    ?(max_balls = defaults.max_balls) ?(max_turns = defaults.max_turns)
    ?heavy_chipper slots =
  build_policy ~ball_name ~max_balls ~max_turns
    ~foe_hp_rechip:defaults.kyogre_rechip ~heavy_chipper slots

let groudon_policy ?(ball_name = defaults.ball_name)
    ?(max_balls = defaults.max_balls) ?(max_turns = defaults.max_turns)
    ?heavy_chipper slots =
  build_policy ~ball_name ~max_balls ~max_turns
    ~foe_hp_rechip:extra.groudon_rechip ~heavy_chipper slots
