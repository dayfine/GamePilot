type event =
  | Action_menu of Catch_state.t
  | Forced_switch of { fainted_slot : int }
  | Caught
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
  | Paused of { reason : string; summary : summary }
  | Failed of { reason : string; summary : summary }

let empty_summary = { turns = 0; balls_thrown = 0; switches = 0; heals = 0 }

let is_wall_heal (policy : Catch_state.policy) (state : Catch_state.t) slot =
  state.active_slot = policy.wall.slot && policy.wall.heal_move_slot = Some slot

let record_command policy state summary = function
  | Catch_state.Throw_ball _ ->
      {
        summary with
        turns = summary.turns + 1;
        balls_thrown = summary.balls_thrown + 1;
      }
  | Switch_to _ ->
      {
        summary with
        turns = summary.turns + 1;
        switches = summary.switches + 1;
      }
  | Heal_active ->
      { summary with turns = summary.turns + 1; heals = summary.heals + 1 }
  | Use_move slot when is_wall_heal policy state slot ->
      { summary with turns = summary.turns + 1; heals = summary.heals + 1 }
  | Use_move _ | Pause_for_user _ -> { summary with turns = summary.turns + 1 }

let sync_state (state : Catch_state.t) summary =
  {
    state with
    turn = max state.turn summary.turns;
    balls_thrown = max state.balls_thrown summary.balls_thrown;
  }

let handle_action_menu ~log steps policy summary state =
  let state = sync_state state summary in
  match Catch_policy.decide policy state with
  | Catch_state.Pause_for_user reason ->
      log ("Pausing: " ^ reason);
      Either.Right (Paused { reason; summary })
  | cmd -> (
      log ("Action: " ^ Catch_state.describe_command cmd);
      match steps.execute cmd with
      | Ok () -> Either.Left (record_command policy state summary cmd)
      | Error reason -> Either.Right (Failed { reason; summary }))

let handle_forced_switch ~log steps policy fainted summary fainted_slot =
  let fainted =
    if List.mem fainted_slot fainted then fainted else fainted_slot :: fainted
  in
  match Catch_policy.next_send_in policy ~fainted with
  | None ->
      let reason = "no healthy send-in left" in
      log ("Pausing: " ^ reason);
      Either.Right (Paused { reason; summary })
  | Some slot -> (
      log (Printf.sprintf "Forced switch: sending in slot %d" slot);
      match steps.send_in slot with
      | Ok () ->
          Either.Left (fainted, { summary with switches = summary.switches + 1 })
      | Error reason -> Either.Right (Failed { reason; summary }))

let run ?(log = ignore) steps policy =
  let rec loop fainted summary =
    match steps.next_event () with
    | Error reason -> Failed { reason; summary }
    | Ok Caught ->
        log "Target caught!";
        Caught summary
    | Ok Battle_lost -> Failed { reason = "battle lost"; summary }
    | Ok (Unexpected reason) ->
        log ("Pausing on unexpected event: " ^ reason);
        Paused { reason; summary }
    | Ok (Action_menu state) -> (
        match handle_action_menu ~log steps policy summary state with
        | Either.Left summary -> loop fainted summary
        | Either.Right outcome -> outcome)
    | Ok (Forced_switch { fainted_slot }) -> (
        match
          handle_forced_switch ~log steps policy fainted summary fainted_slot
        with
        | Either.Left (fainted, summary) -> loop fainted summary
        | Either.Right outcome -> outcome)
  in
  loop [] empty_summary
