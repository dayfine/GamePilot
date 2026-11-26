open Bdsp_underground
module H = Switch_home.Held_screen
module P = Switch_home.Switch_presses

let ( let* ) = Result.bind
let tool_hold_ms = 100
let tool_cooldown_ms = 250
let cursor_hold_ms = 60
let cursor_cooldown_ms = 80
let strike_hold_ms = 80
let strike_cooldown_ms = 350
let dig_start_col = 6
let dig_start_row = 4
let dig_default_announced = 3
let dig_max_moves = 65
let dig_frame_timeout_ms = 1000
let dig_post_strike_settle_ms = 220
let dig_max_hits_per_cell = 3
let wall_appear_timeout_ms = 8000
let wall_clear_hold_ms = 200.
let min_covered_cells_visible = 20
let log_grid_period = 8

let pickaxe_decay_kernel =
  [ (0, 0, 2); (-1, 0, 1); (1, 0, 1); (0, -1, 1); (0, 1, 1) ]

let hammer_decay_kernel =
  [
    (0, 0, 2);
    (-1, 0, 2);
    (1, 0, 2);
    (0, -1, 2);
    (0, 1, 2);
    (-1, -1, 1);
    (1, -1, 1);
    (-1, 1, 1);
    (1, 1, 1);
  ]

let toggle_mining_tool () =
  P.press ~hold_ms:tool_hold_ms ~cooldown_ms:tool_cooldown_ms Wire.R

let repeat_cursor btn n =
  for _ = 1 to abs n do
    P.press ~hold_ms:cursor_hold_ms ~cooldown_ms:cursor_cooldown_ms btn
  done

let mining_move_cursor ~dx ~dy =
  if dx > 0 then repeat_cursor Wire.Right dx
  else if dx < 0 then repeat_cursor Wire.Left dx;
  if dy > 0 then repeat_cursor Wire.Down dy
  else if dy < 0 then repeat_cursor Wire.Up dy

let mining_strike () =
  P.press ~hold_ms:strike_hold_ms ~cooldown_ms:strike_cooldown_ms Wire.A

let decay_cell prev dmg c r =
  if Mining_wall.in_bounds ~col:c ~row:r then
    match prev.(r).(c) with
    | Mining_wall.Covered d ->
        prev.(r).(c) <-
          (if d <= dmg then Mining_wall.Clear_empty
           else Mining_wall.Covered (d - dmg))
    | _ -> ()

let decay_prev_grid prev ~tool ~col ~row =
  let kernel =
    match tool with
    | Mining_wall.Pickaxe -> pickaxe_decay_kernel
    | Mining_wall.Hammer -> hammer_decay_kernel
  in
  List.iter
    (fun (dc, dr, dmg) -> decay_cell prev dmg (col + dc) (row + dr))
    kernel

let ensure_tool ~actual current wanted =
  let cur = Option.value actual ~default:!current in
  if cur <> wanted then (
    toggle_mining_tool ();
    current := wanted)
  else current := cur

let move_and_hit cur_c cur_r ~col ~row =
  let dx = col - !cur_c and dy = row - !cur_r in
  mining_move_cursor ~dx ~dy;
  cur_c := col;
  cur_r := row;
  mining_strike ();
  P.wait dig_post_strike_settle_ms

let cell_char = function
  | Mining_wall.Covered d -> Char.chr (Char.code '0' + min 9 d)
  | Mining_wall.Clear_empty -> '.'
  | Mining_wall.Clear_iron -> '#'
  | Mining_wall.Clear_item { kind = Mining_goal.Shard_l; _ } -> 'L'
  | Mining_wall.Clear_item { kind = Mining_goal.Shard_s; _ } -> 'S'
  | Mining_wall.Clear_item { kind = Mining_goal.Other; _ } -> 'o'

let log_grid ~log (obs : Mining_wall.observation) =
  for r = 0 to obs.rows - 1 do
    let line = String.init obs.cols (fun c -> cell_char obs.grid.(r).(c)) in
    log (Printf.sprintf "grid[%d]: %s" r line)
  done

let covered_count (obs : Mining_wall.observation) =
  let count = ref 0 in
  for r = 0 to obs.rows - 1 do
    for c = 0 to obs.cols - 1 do
      match obs.grid.(r).(c) with
      | Mining_wall.Covered _ -> incr count
      | _ -> ()
    done
  done;
  !count

let wait_wall_visible () =
  let wall_ready m =
    let obs =
      Bdsp_readers.Mining_grid.read_observation
        ~announced_items:dig_default_announced
        ~integrity:Mining_wall.max_integrity m
    in
    if covered_count obs >= min_covered_cells_visible then Some () else None
  in
  match
    H.wait_for ~timeout_ms:wall_appear_timeout_ms
      (H.held wall_clear_hold_ms wall_ready)
  with
  | Some () -> Ok ()
  | None -> Error "dig_wall_smart: mining wall never appeared"

let mask_exhausted_cells hits (obs : Mining_wall.observation) =
  for r = 0 to obs.rows - 1 do
    for c = 0 to obs.cols - 1 do
      if hits.(r).(c) >= dig_max_hits_per_cell then
        match obs.grid.(r).(c) with
        | Mining_wall.Covered _ -> obs.grid.(r).(c) <- Mining_wall.Clear_empty
        | _ -> ()
    done
  done

type dig_state = {
  cur_c : int ref;
  cur_r : int ref;
  cur_tool : Mining_wall.tool ref;
  integrity : int ref;
  prev_grid : Mining_wall.visible_cell array array option ref;
  hits : int array array;
}

let tool_name = function
  | Mining_wall.Hammer -> "Hammer"
  | Mining_wall.Pickaxe -> "Pickaxe"

let execute_action ~log ~actual_tool st ~moves ~bailed obs = function
  | Mining_solver.Bail_collapse ->
      if not bailed then log "No wanted shards found; bailing with Hammer!";
      ensure_tool ~actual:actual_tool st.cur_tool Mining_wall.Hammer;
      mining_strike ();
      P.wait dig_post_strike_settle_ms;
      st.integrity := max 0 (!(st.integrity) - Mining_wall.hammer_cost);
      st.prev_grid := Some obs.Mining_wall.grid;
      true
  | Mining_solver.Strike { tool; col; row } ->
      log
        (Printf.sprintf "Move %d: %s (%d,%d)" (moves + 1) (tool_name tool) col
           row);
      ensure_tool ~actual:actual_tool st.cur_tool tool;
      move_and_hit st.cur_c st.cur_r ~col ~row;
      st.hits.(row).(col) <- st.hits.(row).(col) + 1;
      decay_prev_grid obs.grid ~tool ~col ~row;
      st.prev_grid := Some obs.grid;
      st.integrity := max 0 (!(st.integrity) - Mining_wall.tool_cost tool);
      bailed

let step_dig ~log ~goal ~tally st ~moves ~bailed m =
  let actual_tool = Bdsp_readers.Mining_grid.selected_tool m in
  let obs =
    Bdsp_readers.Mining_grid.read_observation ~cursor:(!(st.cur_c), !(st.cur_r))
      ?prev:!(st.prev_grid) ~announced_items:dig_default_announced
      ~integrity:!(st.integrity) m
  in
  mask_exhausted_cells st.hits obs;
  if moves = 0 || moves mod log_grid_period = 0 then log_grid ~log obs;
  let act = Mining_solver.decide ~goal ~tally obs in
  execute_action ~log ~actual_tool st ~moves ~bailed obs act

let make_dig_state () =
  {
    cur_c = ref dig_start_col;
    cur_r = ref dig_start_row;
    cur_tool = ref Mining_wall.Pickaxe;
    integrity = ref Mining_wall.max_integrity;
    prev_grid = ref None;
    hits = Array.init Mining_wall.rows (fun _ -> Array.make Mining_wall.cols 0);
  }

let dig_wall_smart ~log ~picture ~goal ~tally () =
  ignore
    (Effects.subscribe
       (Bdsp_readers.Dialog_detector.probes ~picture
       @ Bdsp_readers.Mining_grid.probes ~picture)
      : string list);
  let* () = wait_wall_visible () in
  let st = make_dig_state () in
  let rec loop moves bailed =
    if moves >= dig_max_moves then Ok (moves, bailed)
    else
      match Effects.await ~timeout_ms:dig_frame_timeout_ms (fun _ -> true) with
      | Effects.Timeout -> Error "dig_wall_smart: timed out waiting for frame"
      | Effects.Holds m when Bdsp_readers.Dialog_detector.shown m ->
          log "Wall finished / collapsed dialog detected.";
          Ok (moves, bailed)
      | Effects.Holds m ->
          let next_bailed = step_dig ~log ~goal ~tally st ~moves ~bailed m in
          loop (moves + 1) next_bailed
  in
  loop 0 false
