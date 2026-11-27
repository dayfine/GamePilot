module B = Switch.Black_screen
module H = Screen_graph.Held_screen
module P = Switch.Switch_presses
module Hud = Bdsp_readers.Battle_hud
module CS = Pokemon_catch.Catch_state
module CR = Pokemon_catch.Catch_runner
module Cursor = Battle_party_cursor

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
  status_cycle_ms : int;
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

let default_ball_name = "Luxury Ball"
let default_max_balls = 60
let default_max_turns = 80
let default_hp_floor = 0.40
let default_foe_target = 0.15
let kyogre_rechip = 0.35
let groudon_rechip = 0.40
let poll_slice_ms = 500

let default_timing : timing =
  {
    press_hold_ms = 80;
    press_cooldown_ms = 240;
    nav_cooldown_ms = 180;
    menu_settle_ms = 450;
    event_timeout_ms = 30_000;
    dialog_advance_ms = 350;
    black_hold_ms = 200.;
    status_cycle_ms = 2200;
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

let select_party_row t row =
  nav_repeat t Wire.Down row;
  tap t Wire.A;
  tap t Wire.A

type tracker = {
  mutable subscribed : bool;
  mutable turns : int;
  mutable balls_thrown : int;
  mutable last_ball : string option;
  cursor : Cursor.t;
}

let ensure_probes cfg tr =
  if not tr.subscribed then (
    ignore
      (Effects.subscribe (Hud.all_battle_probes ~picture:cfg.picture)
        : string list);
    tr.subscribed <- true)

let saw_sleep m = Hud.foe_asleep m = Some true

let sample_foe_asleep cfg first_m =
  match Hud.foe_asleep first_m with
  | Some true -> Some CS.Asleep
  | None -> None
  | Some false when cfg.timing.status_cycle_ms <= 0 -> Some CS.Healthy
  | Some false -> (
      match Effects.await ~timeout_ms:cfg.timing.status_cycle_ms saw_sleep with
      | Effects.Holds _ -> Some CS.Asleep
      | Effects.Timeout -> Some CS.Healthy)

let read_action_state cfg tr m : CS.t =
  {
    turn = tr.turns;
    active_slot = Cursor.active_slot tr.cursor;
    active_hp_ratio = Hud.player_hp_ratio m;
    foe_hp_ratio = Hud.foe_hp_ratio m;
    foe_status = sample_foe_asleep cfg m;
    balls_thrown = tr.balls_thrown;
    fainted = [];
    setup_uses_done = 0;
    wall_move_heals_done = 0;
    status_uses_done = 0;
  }

let is_not_black m = if not (B.shown m) then Some () else None

let wait_battle_end ~log cfg tr =
  let t = cfg.timing in
  if tr.balls_thrown <= 0 then
    Ok (CR.Unexpected "black screen before any ball was thrown")
  else (
    log "Battle faded to black after ball throw; waiting for fade clear...";
    ignore
      (H.wait_for ~timeout_ms:t.event_timeout_ms
         (H.held t.black_hold_ms is_not_black));
    Ok (CR.Caught : CR.event))

let inspect_frame ~log cfg tr m =
  let t = cfg.timing in
  match Hud.classify_screen m with
  | Hud.Action_menu -> Some (Ok (CR.Action_menu (read_action_state cfg tr m)))
  | Hud.Forced_switch ->
      Some
        (Ok (CR.Forced_switch { fainted_slot = Cursor.active_slot tr.cursor }))
  | Hud.Dialog ->
      P.press ~hold_ms:t.press_hold_ms ~cooldown_ms:t.dialog_advance_ms Wire.A;
      None
  | Hud.Black -> Some (wait_battle_end ~log cfg tr)
  | Hud.Other -> None

let is_event_screen m = Hud.classify_screen m <> Hud.Other

let rec poll_event ~log cfg tr deadline =
  let remaining = int_of_float (deadline -. Effects.now ()) in
  if remaining <= 0 then
    Ok (CR.Unexpected "timed out waiting for BDSP battle event")
  else
    let slice = min remaining poll_slice_ms in
    match Effects.await ~timeout_ms:slice is_event_screen with
    | Effects.Timeout -> poll_event ~log cfg tr deadline
    | Effects.Holds m -> (
        match inspect_frame ~log cfg tr m with
        | Some res -> res
        | None -> poll_event ~log cfg tr deadline)

let next_event ~log cfg tr () =
  ensure_probes cfg tr;
  let deadline = Effects.now () +. float_of_int cfg.timing.event_timeout_ms in
  poll_event ~log cfg tr deadline

let move_cursor_delta t ~from_slot ~to_slot =
  let diff = to_slot - from_slot in
  if diff > 0 then nav_repeat t Wire.Down diff
  else if diff < 0 then nav_repeat t Wire.Up (-diff)

let settle_after_action t = P.wait (t.menu_settle_ms * 3)

let finish_turn t tr =
  tr.turns <- tr.turns + 1;
  settle_after_action t;
  Ok ()

let open_submenu t down_rows =
  nav_repeat t Wire.Down down_rows;
  tap t Wire.A;
  P.wait t.menu_settle_ms

let use_move ~log cfg tr move_slot =
  let t = cfg.timing and prev = Cursor.last_move tr.cursor in
  log (Printf.sprintf "BDSP: Fight -> move %d (from %d)" move_slot prev);
  open_submenu t 0;
  move_cursor_delta t ~from_slot:prev ~to_slot:move_slot;
  tap t Wire.A;
  Cursor.record_move tr.cursor move_slot;
  finish_turn t tr

let throw_ball ~log cfg tr ~fallback_ball_steps name =
  let t = cfg.timing in
  log ("BDSP: X-shortcut -> throw " ^ name);
  tap t Wire.X;
  P.wait t.menu_settle_ms;
  (match tr.last_ball with
  | None -> move_pockets t cfg.bag.ball_row
  | Some prev when prev <> name -> move_pockets t fallback_ball_steps
  | Some _ -> ());
  tap t Wire.A;
  tr.last_ball <- Some name;
  tr.balls_thrown <- tr.balls_thrown + 1;
  finish_turn t tr

let execute_command ~log cfg tr ~fallback_ball_steps = function
  | CS.Use_move move_slot -> use_move ~log cfg tr move_slot
  | CS.Switch_to slot ->
      let t = cfg.timing and row = Cursor.swap_to tr.cursor slot in
      log (Printf.sprintf "BDSP: Pokémon -> slot %d (row %d)" slot row);
      open_submenu t 1;
      select_party_row t row;
      finish_turn t tr
  | CS.Throw_ball name -> throw_ball ~log cfg tr ~fallback_ball_steps name
  | CS.Heal_active ->
      let t = cfg.timing in
      log
        (Printf.sprintf "BDSP: Bag -> heal slot %d"
           (Cursor.active_slot tr.cursor));
      open_submenu t 2;
      move_pockets t cfg.bag.heal_pocket_steps;
      nav_repeat t Wire.Down cfg.bag.heal_row;
      nav_repeat t Wire.A 3;
      finish_turn t tr
  | CS.Pause_for_user _ -> Ok ()

let send_in ~log cfg tr slot =
  let t = cfg.timing and row = Cursor.swap_to tr.cursor slot in
  log (Printf.sprintf "BDSP: forced switch -> slot %d (row %d)" slot row);
  P.wait t.menu_settle_ms;
  select_party_row t row;
  settle_after_action t;
  Ok ()

let make ?(log = ignore) ?(initial_move_slot = 1) ?(fallback_ball_steps = 0) cfg
    : CR.game_steps =
  let cursor =
    Cursor.create ~party_size:6 ~initial_active_slot:cfg.initial_active_slot
  in
  if initial_move_slot <> 1 then Cursor.record_move cursor initial_move_slot;
  let tr =
    {
      subscribed = false;
      turns = 0;
      balls_thrown = 0;
      last_ball = None;
      cursor;
    }
  in
  {
    next_event = next_event ~log cfg tr;
    execute = execute_command ~log cfg tr ~fallback_ball_steps;
    send_in = send_in ~log cfg tr;
  }

let build_policy ~ball_name ~max_balls ~max_turns ~foe_hp_rechip ~heavy_chipper
    (s : party_slots) : CS.policy =
  let f = default_hp_floor in
  {
    status_setter =
      Some { slot = s.status_setter; move_slot = s.status_move; hp_floor = f };
    setup = None;
    heavy_chipper;
    false_swiper =
      Some
        {
          slot = s.false_swiper;
          move_slot = s.false_swipe_move;
          require_status = true;
          hp_floor = f;
        };
    wall =
      Some { slot = s.wall; heal_move_slot = s.wall_heal_move; hp_floor = f };
    ball_name;
    fallback_ball = None;
    max_balls;
    foe_hp_target = default_foe_target;
    foe_hp_rechip;
    reapply_status = true;
    max_turns;
    send_in_order = s.send_in_order;
  }

let kyogre_policy ?(ball_name = default_ball_name)
    ?(max_balls = default_max_balls) ?(max_turns = default_max_turns)
    ?heavy_chipper slots =
  build_policy ~ball_name ~max_balls ~max_turns ~foe_hp_rechip:kyogre_rechip
    ~heavy_chipper slots

let groudon_policy ?(ball_name = default_ball_name)
    ?(max_balls = default_max_balls) ?(max_turns = default_max_turns)
    ?heavy_chipper slots =
  build_policy ~ball_name ~max_balls ~max_turns ~foe_hp_rechip:groudon_rechip
    ~heavy_chipper slots
