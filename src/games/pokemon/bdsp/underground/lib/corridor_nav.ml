type sparkle_target = {
  offset_tiles : int;
  wall_side : Grid_geometry.Direction.t;
}

type doorway_anchor = {
  enter_dir : Grid_geometry.Direction.t;
  exit_dir : Grid_geometry.Direction.t;
}

type walk_outcome = At_wall | Wild_battle
type refresh_outcome = Refreshed | Refresh_wild_battle

type game_steps = {
  pulse_radar : unit -> (sparkle_target list, string) result;
  walk_to_sparkle : sparkle_target -> (walk_outcome, string) result;
  dig_wall : unit -> (Mining_goal.item list * bool, string) result;
  bounce_hideaway_door : doorway_anchor -> (refresh_outcome, string) result;
  run_from_battle : unit -> (unit, string) result;
  save_game : unit -> (unit, string) result;
}

type session_summary = {
  tally : Mining_goal.tally;
  refreshes : int;
  battles_escaped : int;
  saves : int;
}

let ( let* ) = Result.bind

let maybe_save ~save_every ~steps summary =
  let digs = summary.tally.Mining_goal.digs in
  if save_every > 0 && digs > 0 && digs mod save_every = 0 then
    let* () = steps.save_game () in
    Ok { summary with saves = summary.saves + 1 }
  else Ok summary

let handle_sparkle ~save_every ~steps summary target =
  let* outcome = steps.walk_to_sparkle target in
  match outcome with
  | Wild_battle ->
      let* () = steps.run_from_battle () in
      Ok { summary with battles_escaped = summary.battles_escaped + 1 }
  | At_wall ->
      let* items, bailed = steps.dig_wall () in
      let tally = Mining_goal.record_dig summary.tally ~bailed items in
      maybe_save ~save_every ~steps { summary with tally }

let rec sweep_sparkles ~goal ~save_every ~steps summary = function
  | [] -> Ok summary
  | target :: rest ->
      if Mining_goal.is_met goal summary.tally then Ok summary
      else
        let* next = handle_sparkle ~save_every ~steps summary target in
        sweep_sparkles ~goal ~save_every ~steps next rest

let refresh_corridor ~anchor ~steps summary =
  let* outcome = steps.bounce_hideaway_door anchor in
  match outcome with
  | Refreshed -> Ok { summary with refreshes = summary.refreshes + 1 }
  | Refresh_wild_battle ->
      let* () = steps.run_from_battle () in
      Ok
        {
          summary with
          refreshes = summary.refreshes + 1;
          battles_escaped = summary.battles_escaped + 1;
        }

let run_session ~goal ~anchor ~save_every ~max_refreshes ~steps =
  let init =
    {
      tally = Mining_goal.empty_tally;
      refreshes = 0;
      battles_escaped = 0;
      saves = 0;
    }
  in
  let rec loop summary =
    if Mining_goal.is_met goal summary.tally then Ok summary
    else if summary.refreshes >= max_refreshes then
      Error "max_refreshes reached before goal was met"
    else
      let* targets = steps.pulse_radar () in
      let* after_sweep =
        sweep_sparkles ~goal ~save_every ~steps summary targets
      in
      if Mining_goal.is_met goal after_sweep.tally then Ok after_sweep
      else
        let* after_refresh = refresh_corridor ~anchor ~steps after_sweep in
        loop after_refresh
  in
  loop init
