module B = Frlg_battle.Battle
module BL = Frlg_battle.Battle_look
module BS = Frlg_battle.Battle_steps
module Hud = Frlg_readers.Battle_hud
module Bag = Frlg_readers.Bag_screen
module CS = Pokemon_catch.Catch_state
module CR = Pokemon_catch.Catch_runner

type bag_layout = { ball_row : int; heal_row : int }

type config = {
  initial_active_slot : int;
  bag : bag_layout;
  event_timeout_ms : int;
}

type phase1_slots = {
  sleeper_slot : int;
  spore_move : int;
  swiper_slot : int;
  false_swipe_move : int;
  use_sleeper_as_wall : bool;
  send_in_order : int list;
}

type phase2_slots = {
  catcher_slot : int;
  spore_move : int;
  false_swipe_move : int;
  send_in_order : int list;
}

let default_ball_name = "ultra-ball"
let default_max_balls = 60
let default_max_turns = 80
let default_hp_floor = 0.35
let default_foe_hp_target = 0.15
let default_foe_hp_rechip = 0.25
let default_event_timeout_ms = 30_000

let default_config : config =
  {
    initial_active_slot = 1;
    bag = { ball_row = 0; heal_row = 0 };
    event_timeout_ms = default_event_timeout_ms;
  }

let default_phase1_slots : phase1_slots =
  {
    sleeper_slot = 1;
    spore_move = 1;
    swiper_slot = 2;
    false_swipe_move = 1;
    use_sleeper_as_wall = true;
    send_in_order = [ 1; 2; 3; 4; 5 ];
  }

let default_phase2_slots : phase2_slots =
  {
    catcher_slot = 1;
    spore_move = 1;
    false_swipe_move = 2;
    send_in_order = [ 1; 2; 3; 4 ];
  }

type tracker = {
  mutable subscribed : bool;
  mutable active_slot : int;
  (* Live 0-based battle party order: switching swaps index 0 (active) with the
     chosen bench index, so logical slot numbers move as switches happen. *)
  party_order : int array;
  mutable turns : int;
  mutable balls_thrown : int;
  mutable last_action_was_throw : bool;
  mutable pending_event : CR.event option;
}

let find_battle_index tr logical_slot =
  Array.find_index (( = ) logical_slot) tr.party_order

let swap_into_lead tr idx =
  let cur = tr.party_order.(0) in
  tr.party_order.(0) <- tr.party_order.(idx);
  tr.party_order.(idx) <- cur

let ensure_probes tr =
  if not tr.subscribed then (
    ignore (Effects.subscribe (BL.probes @ Hud.probes) : string list);
    tr.subscribed <- true)

let map_foe_status : Hud.foe_status -> CS.foe_status = function
  | Hud.Healthy -> CS.Healthy
  | Hud.Asleep -> CS.Asleep
  | Hud.Paralyzed -> CS.Paralyzed
  | Hud.Other_status -> CS.Other_status

let state_of_frame tr m : CS.t =
  {
    turn = tr.turns;
    active_slot = tr.active_slot;
    active_hp_ratio = Option.bind m Hud.player_hp_ratio;
    foe_hp_ratio = Option.bind m Hud.foe_hp_ratio;
    foe_status = Option.map map_foe_status (Option.bind m Hud.foe_status);
    balls_thrown = tr.balls_thrown;
    fainted = [];
  }

let rec next_live_event ~log (battle : B.game_steps) cfg tr =
  ensure_probes tr;
  match battle.next_event ~timeout_ms:cfg.event_timeout_ms with
  | B.Action_menu ->
      tr.last_action_was_throw <- false;
      Ok (CR.Action_menu (state_of_frame tr (Effects.read ())))
  | B.Use_next ->
      log "FRLG catch: answering YES to 'Use next POKéMON?'";
      battle.answer_use_next true;
      next_live_event ~log battle cfg tr
  | B.Switch_in -> Ok (CR.Forced_switch { fainted_slot = tr.active_slot })
  | B.Battle_over ->
      Ok (if tr.last_action_was_throw then CR.Caught else CR.Foe_ended)
  | B.Move_learn when tr.last_action_was_throw -> Ok CR.Caught
  | B.Timed_out -> Ok (CR.Unexpected "timed out waiting for FRLG battle event")
  | (B.Level_up | B.Move_learn | B.Evolution | B.Switch_offer) as ev ->
      Ok (CR.Unexpected ("unexpected battle prompt: " ^ B.event_name ev))

let next_event ~log battle cfg tr () =
  match tr.pending_event with
  | Some ev ->
      tr.pending_event <- None;
      Ok ev
  | None -> next_live_event ~log battle cfg tr

let execute_move ~log (battle : B.game_steps) tr move_slot =
  log (Printf.sprintf "FRLG catch: Fight -> move %d" move_slot);
  tr.last_action_was_throw <- false;
  match
    battle.use_move ~slot:(move_slot - 1) ~target:B.Default ~expect:None
  with
  | B.Chosen ->
      tr.turns <- tr.turns + 1;
      Ok ()
  | B.Refused ->
      let msg =
        Printf.sprintf "move slot %d refused (0 PP or disabled)" move_slot
      in
      tr.pending_event <- Some (CR.Unexpected msg);
      Ok ()
  | B.Other_move name -> Error ("unexpected move in slot: " ^ name)
  | B.Not_done reason -> Error reason

let finish_switch ~inc_turn tr slot idx =
  swap_into_lead tr idx;
  tr.active_slot <- slot;
  if inc_turn then tr.turns <- tr.turns + 1;
  Ok ()

let switch_slot ~log ~action ~err_verb ~inc_turn ~do_switch tr slot =
  match find_battle_index tr slot with
  | None -> Error (Printf.sprintf "unknown party slot %d" slot)
  | Some idx ->
      log
        (Printf.sprintf "FRLG catch: %s -> slot %d (pos %d)" action slot
           (idx + 1));
      tr.last_action_was_throw <- false;
      if do_switch ~slot:idx then finish_switch ~inc_turn tr slot idx
      else Error (Printf.sprintf "could not %s party slot %d" err_verb slot)

let execute_switch ~log (battle : B.game_steps) tr slot =
  switch_slot ~log ~action:"Pokémon" ~err_verb:"switch to" ~inc_turn:true
    ~do_switch:battle.switch_to tr slot

let execute_throw ~log (battle : B.game_steps) cfg tr name =
  log ("FRLG catch: Bag -> throw " ^ name);
  let item : B.item =
    { pocket = Bag.Poke_balls; row = cfg.bag.ball_row; on_slot = None }
  in
  if battle.use_item item then (
    tr.balls_thrown <- tr.balls_thrown + 1;
    tr.turns <- tr.turns + 1;
    tr.last_action_was_throw <- true;
    Ok ())
  else (
    tr.last_action_was_throw <- false;
    tr.pending_event <- Some CR.No_balls;
    Ok ())

let execute_heal ~log (battle : B.game_steps) cfg tr =
  log (Printf.sprintf "FRLG catch: Bag -> heal slot %d" tr.active_slot);
  tr.last_action_was_throw <- false;
  let item : B.item =
    { pocket = Bag.Items; row = cfg.bag.heal_row; on_slot = Some 0 }
  in
  if battle.use_item item then (
    tr.turns <- tr.turns + 1;
    Ok ())
  else Error (Printf.sprintf "could not heal party slot %d" tr.active_slot)

let execute_command ~log battle cfg tr = function
  | CS.Use_move move_slot -> execute_move ~log battle tr move_slot
  | CS.Switch_to slot -> execute_switch ~log battle tr slot
  | CS.Throw_ball name -> execute_throw ~log battle cfg tr name
  | CS.Heal_active -> execute_heal ~log battle cfg tr
  | CS.Pause_for_user _ -> Ok ()

let send_in ~log (battle : B.game_steps) tr slot =
  switch_slot ~log ~action:"forced switch" ~err_verb:"send in" ~inc_turn:false
    ~do_switch:battle.send_in tr slot

let make ?battle ?(log = ignore) cfg : CR.game_steps =
  let battle = Option.value ~default:(BS.make ~log ()) battle in
  let tr =
    {
      subscribed = false;
      active_slot = cfg.initial_active_slot;
      party_order = [| 1; 2; 3; 4; 5; 6 |];
      turns = 0;
      balls_thrown = 0;
      last_action_was_throw = false;
      pending_event = None;
    }
  in
  Option.iter
    (fun idx -> if idx > 0 then swap_into_lead tr idx)
    (find_battle_index tr cfg.initial_active_slot);
  {
    next_event = next_event ~log battle cfg tr;
    execute = execute_command ~log battle cfg tr;
    send_in = send_in ~log battle tr;
  }

let build_policy ~ball_name ~max_balls ~max_turns ~sleeper_slot ~spore_move
    ~swiper_slot ~false_swipe_move ~wall ~send_in_order : CS.policy =
  let hp_floor = default_hp_floor in
  {
    status_setter =
      Some { slot = sleeper_slot; move_slot = spore_move; hp_floor };
    false_swiper =
      Some
        {
          slot = swiper_slot;
          move_slot = false_swipe_move;
          require_status = true;
          hp_floor;
        };
    wall;
    ball_name;
    max_balls;
    foe_hp_target = default_foe_hp_target;
    foe_hp_rechip = default_foe_hp_rechip;
    reapply_status = true;
    max_turns;
    send_in_order;
  }

let phase1_policy ?(ball_name = default_ball_name)
    ?(max_balls = default_max_balls) ?(max_turns = default_max_turns)
    (s : phase1_slots) : CS.policy =
  let wall : CS.wall_config option =
    if s.use_sleeper_as_wall then
      Some
        {
          slot = s.sleeper_slot;
          heal_move_slot = None;
          hp_floor = default_hp_floor;
        }
    else None
  in
  build_policy ~ball_name ~max_balls ~max_turns ~sleeper_slot:s.sleeper_slot
    ~spore_move:s.spore_move ~swiper_slot:s.swiper_slot
    ~false_swipe_move:s.false_swipe_move ~wall ~send_in_order:s.send_in_order

let phase2_policy ?(ball_name = default_ball_name)
    ?(max_balls = default_max_balls) ?(max_turns = default_max_turns)
    (s : phase2_slots) : CS.policy =
  build_policy ~ball_name ~max_balls ~max_turns ~sleeper_slot:s.catcher_slot
    ~spore_move:s.spore_move ~swiper_slot:s.catcher_slot
    ~false_swipe_move:s.false_swipe_move ~wall:None
    ~send_in_order:s.send_in_order

let spore_ball_policy ?(ball_name = default_ball_name)
    ?(max_balls = default_max_balls) ?(max_turns = default_max_turns) () :
    CS.policy =
  {
    status_setter =
      Some { slot = 1; move_slot = 1; hp_floor = default_hp_floor };
    false_swiper = None;
    wall = None;
    ball_name;
    max_balls;
    foe_hp_target = 1.0;
    foe_hp_rechip = 1.0;
    reapply_status = true;
    max_turns;
    send_in_order = default_phase1_slots.send_in_order;
  }
