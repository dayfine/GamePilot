type event =
  | Action_menu of Catch_state.t
  | Forced_switch of { fainted_slot : int }
  | Caught
  | No_balls
  | Foe_ended
  | Battle_lost
  | Unexpected of string

type game_steps = {
  next_event : unit -> (event, string) result;
  execute : Catch_state.command -> (unit, string) result;
  send_in : int -> (unit, string) result;
}

type summary = { turns : int; balls_thrown : int; switches : int; heals : int }

type outcome =
  | Caught of summary
  | No_balls of summary
  | Foe_ended of summary
  | Paused of { reason : string; summary : summary }
  | Failed of { reason : string; summary : summary }

let empty_summary = { turns = 0; balls_thrown = 0; switches = 0; heals = 0 }

let is_wall_heal (policy : Catch_state.policy) (state : Catch_state.t) slot =
  match policy.wall with
  | Some w -> state.active_slot = w.slot && w.heal_move_slot = Some slot
  | None -> false

let is_setup_move (policy : Catch_state.policy) (state : Catch_state.t) slot =
  match policy.setup with
  | Some su -> state.active_slot = su.slot && su.move_slot = slot
  | None -> false

let is_status_move (policy : Catch_state.policy) (state : Catch_state.t) slot =
  match policy.status_setter with
  | Some ss -> state.active_slot = ss.slot && ss.move_slot = slot
  | None -> false

type counters = {
  summary : summary;
  setup_uses : int;
  wall_move_heals : int;
  status_uses : int;
}

let empty_counters =
  {
    summary = empty_summary;
    setup_uses = 0;
    wall_move_heals = 0;
    status_uses = 0;
  }

let bump_turn s = { s with turns = s.turns + 1 }

let record_command policy state c = function
  | Catch_state.Throw_ball _ ->
      let summary =
        { (bump_turn c.summary) with balls_thrown = c.summary.balls_thrown + 1 }
      in
      { c with summary }
  | Switch_to _ ->
      let summary =
        { (bump_turn c.summary) with switches = c.summary.switches + 1 }
      in
      { c with summary }
  | Heal_active ->
      let summary =
        { (bump_turn c.summary) with heals = c.summary.heals + 1 }
      in
      { c with summary }
  | Use_move slot when is_wall_heal policy state slot ->
      let summary =
        { (bump_turn c.summary) with heals = c.summary.heals + 1 }
      in
      { c with summary; wall_move_heals = c.wall_move_heals + 1 }
  | Use_move slot when is_setup_move policy state slot ->
      { c with summary = bump_turn c.summary; setup_uses = c.setup_uses + 1 }
  | Use_move slot when is_status_move policy state slot ->
      { c with summary = bump_turn c.summary; status_uses = c.status_uses + 1 }
  | Use_move _ | Pause_for_user _ -> { c with summary = bump_turn c.summary }

let merge_fainted state_fainted tracked =
  List.fold_left
    (fun acc slot -> if List.mem slot acc then acc else slot :: acc)
    state_fainted tracked

let sync_state (state : Catch_state.t) fainted c =
  {
    state with
    turn = max state.turn c.summary.turns;
    balls_thrown = max state.balls_thrown c.summary.balls_thrown;
    fainted = merge_fainted state.fainted fainted;
    setup_uses_done = max state.setup_uses_done c.setup_uses;
    wall_move_heals_done = max state.wall_move_heals_done c.wall_move_heals;
    status_uses_done = max state.status_uses_done c.status_uses;
  }

let handle_action_menu ~log steps policy fainted c state =
  let state = sync_state state fainted c in
  match Catch_policy.decide policy state with
  | Catch_state.Pause_for_user reason ->
      log ("Pausing: " ^ reason);
      Either.Right (Paused { reason; summary = c.summary })
  | cmd -> (
      log ("Action: " ^ Catch_state.describe_command cmd);
      match steps.execute cmd with
      | Ok () -> Either.Left (record_command policy state c cmd)
      | Error reason -> Either.Right (Failed { reason; summary = c.summary }))

let handle_forced_switch ~log steps policy fainted c fainted_slot =
  let fainted =
    if List.mem fainted_slot fainted then fainted else fainted_slot :: fainted
  in
  match Catch_policy.next_send_in policy ~fainted with
  | None ->
      let reason = "no healthy send-in left" in
      log ("Pausing: " ^ reason);
      Either.Right (Paused { reason; summary = c.summary })
  | Some slot -> (
      log (Printf.sprintf "Forced switch: sending in slot %d" slot);
      match steps.send_in slot with
      | Ok () ->
          let summary = { c.summary with switches = c.summary.switches + 1 } in
          Either.Left (fainted, { c with summary })
      | Error reason -> Either.Right (Failed { reason; summary = c.summary }))

let step ~log steps policy fainted c (ev : (event, string) result) =
  match ev with
  | Error reason -> Either.Right (Failed { reason; summary = c.summary })
  | Ok Caught ->
      log "Target caught!";
      Either.Right (Caught c.summary)
  | Ok No_balls ->
      log "Out of target Poké Balls";
      Either.Right (No_balls c.summary)
  | Ok Foe_ended ->
      log "Wild foe ended the battle";
      Either.Right (Foe_ended c.summary)
  | Ok Battle_lost ->
      Either.Right (Failed { reason = "battle lost"; summary = c.summary })
  | Ok (Unexpected reason) ->
      log ("Pausing on unexpected event: " ^ reason);
      Either.Right (Paused { reason; summary = c.summary })
  | Ok (Action_menu state) -> (
      match handle_action_menu ~log steps policy fainted c state with
      | Either.Left c -> Either.Left (fainted, c)
      | Either.Right outcome -> Either.Right outcome)
  | Ok (Forced_switch { fainted_slot }) ->
      handle_forced_switch ~log steps policy fainted c fainted_slot

let run ?(log = ignore) steps policy =
  let rec loop fainted c =
    match step ~log steps policy fainted c (steps.next_event ()) with
    | Either.Left (fainted, c) -> loop fainted c
    | Either.Right outcome -> outcome
  in
  loop [] empty_counters
