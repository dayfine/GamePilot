open Bdsp_underground
module H = Switch_home.Held_screen
module P = Switch_home.Switch_presses

let ( let* ) = Result.bind

type input_timing = { hold_ms : int; cooldown_ms : int }

type dig_cfg = {
  start_col : int;
  start_row : int;
  default_announced : int;
  max_moves : int;
  frame_timeout_ms : int;
  pickaxe_settle_ms : int;
  hammer_settle_ms : int;
  max_hits_per_cell : int;
}

type wall_cfg = {
  appear_timeout_ms : int;
  clear_hold_ms : float;
  min_covered : int;
  log_period : int;
}

let tool_input = { hold_ms = 100; cooldown_ms = 250 }
let cursor_input = { hold_ms = 60; cooldown_ms = 80 }
let strike_input = { hold_ms = 80; cooldown_ms = 350 }

let dig =
  {
    start_col = 6;
    start_row = 4;
    default_announced = 3;
    max_moves = 65;
    frame_timeout_ms = 1000;
    pickaxe_settle_ms = 420;
    hammer_settle_ms = 800;
    max_hits_per_cell = 3;
  }

let wall_cfg =
  {
    appear_timeout_ms = 8000;
    clear_hold_ms = 200.;
    min_covered = 20;
    log_period = 8;
  }

let pickaxe_decay_kernel =
  [ (0, 0, 2); (-1, 0, 1); (1, 0, 1); (0, -1, 1); (0, 1, 1) ]

let hammer_decay_kernel =
  List.concat_map
    (fun dr ->
      List.map
        (fun dc -> (dc, dr, if dc = 0 || dr = 0 then 2 else 1))
        [ -1; 0; 1 ])
    [ -1; 0; 1 ]

let toggle_mining_tool () =
  P.press ~hold_ms:tool_input.hold_ms ~cooldown_ms:tool_input.cooldown_ms Wire.R

let mining_strike () =
  P.press ~hold_ms:strike_input.hold_ms ~cooldown_ms:strike_input.cooldown_ms
    Wire.A

let repeat_cursor btn n =
  for _ = 1 to abs n do
    P.press ~hold_ms:cursor_input.hold_ms ~cooldown_ms:cursor_input.cooldown_ms
      btn
  done

let mining_move_cursor ~dx ~dy =
  if dx > 0 then repeat_cursor Wire.Right dx
  else if dx < 0 then repeat_cursor Wire.Left dx;
  if dy > 0 then repeat_cursor Wire.Down dy
  else if dy < 0 then repeat_cursor Wire.Up dy

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

let move_and_hit cur_c cur_r ~tool ~col ~row =
  mining_move_cursor ~dx:(col - !cur_c) ~dy:(row - !cur_r);
  cur_c := col;
  cur_r := row;
  mining_strike ();
  P.wait
    (match tool with
    | Mining_wall.Hammer -> dig.hammer_settle_ms
    | Mining_wall.Pickaxe -> dig.pickaxe_settle_ms)

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

let is_covered = function Mining_wall.Covered _ -> true | _ -> false

let covered_count (obs : Mining_wall.observation) =
  Array.fold_left
    (fun acc row ->
      Array.fold_left (fun n c -> n + Bool.to_int (is_covered c)) acc row)
    0 obs.grid

let wait_wall_visible ~announced_ref () =
  let wall_ready m =
    (match Bdsp_readers.Mining_announce_reader.read m with
    | Some n -> announced_ref := Some n
    | None -> ());
    let obs =
      Bdsp_readers.Mining_grid.read_observation
        ~announced_items:dig.default_announced
        ~integrity:Mining_wall.max_integrity m
    in
    if covered_count obs >= wall_cfg.min_covered then Some () else None
  in
  match
    H.wait_for ~timeout_ms:wall_cfg.appear_timeout_ms
      (H.held wall_cfg.clear_hold_ms wall_ready)
  with
  | Some () -> Ok ()
  | None -> Error "dig_wall_smart: mining wall never appeared"

let mask_row hits_row row =
  Array.iteri
    (fun c cell ->
      if hits_row.(c) >= dig.max_hits_per_cell && is_covered cell then
        row.(c) <- Mining_wall.Clear_empty)
    row

let mask_exhausted_cells hits (obs : Mining_wall.observation) =
  Array.iteri (fun r row -> mask_row hits.(r) row) obs.grid

type dig_state = {
  cur_c : int ref;
  cur_r : int ref;
  cur_tool : Mining_wall.tool ref;
  integrity : int ref;
  announced_items : int;
  prev_grid : Mining_wall.visible_cell array array option ref;
  hits : int array array;
}

let tool_name = function Mining_wall.Hammer -> "Hammer" | Pickaxe -> "Pickaxe"

let sync_integrity ~log st m =
  match Bdsp_readers.Mining_grid.crack_gauge_integrity m with
  | Some 0 when !(st.integrity) > 0 ->
      log
        (Printf.sprintf "Crack gauge sync: local=%d -> collapsed"
           !(st.integrity));
      st.integrity := 0
  | _ -> ()

let execute_action ~log ~actual_tool st ~moves ~bailed obs = function
  | Mining_solver.Bail_collapse ->
      if not bailed then log "No wanted shards found; bailing with Hammer!";
      ensure_tool ~actual:actual_tool st.cur_tool Mining_wall.Hammer;
      mining_strike ();
      P.wait dig.hammer_settle_ms;
      st.integrity := max 0 (!(st.integrity) - Mining_wall.hammer_cost);
      st.prev_grid := Some obs.Mining_wall.grid;
      true
  | Mining_solver.Strike { tool; col; row } ->
      log
        (Printf.sprintf "Move %d: %s (%d,%d)" (moves + 1) (tool_name tool) col
           row);
      ensure_tool ~actual:actual_tool st.cur_tool tool;
      move_and_hit st.cur_c st.cur_r ~tool ~col ~row;
      st.hits.(row).(col) <- st.hits.(row).(col) + 1;
      decay_prev_grid obs.grid ~tool ~col ~row;
      st.prev_grid := Some obs.grid;
      st.integrity := max 0 (!(st.integrity) - Mining_wall.tool_cost tool);
      bailed

let step_dig ~log ~goal ~tally st ~moves ~bailed m =
  sync_integrity ~log st m;
  let actual_tool = Bdsp_readers.Mining_grid.selected_tool m in
  let obs =
    Bdsp_readers.Mining_grid.read_observation ~cursor:(!(st.cur_c), !(st.cur_r))
      ?prev:!(st.prev_grid) ~announced_items:st.announced_items
      ~integrity:!(st.integrity) m
  in
  mask_exhausted_cells st.hits obs;
  if moves = 0 || moves mod wall_cfg.log_period = 0 then log_grid ~log obs;
  let act =
    if bailed then Mining_solver.Bail_collapse
    else Mining_solver.decide ~goal ~tally obs
  in
  execute_action ~log ~actual_tool st ~moves ~bailed obs act

let make_dig_state ~announced_items =
  {
    cur_c = ref dig.start_col;
    cur_r = ref dig.start_row;
    cur_tool = ref Mining_wall.Pickaxe;
    integrity = ref Mining_wall.max_integrity;
    announced_items;
    prev_grid = ref None;
    hits = Array.init Mining_wall.rows (fun _ -> Array.make Mining_wall.cols 0);
  }

let min_moves_before_exit = 3

let rec dig_loop ~log ~goal ~tally st moves bailed =
  if moves >= dig.max_moves then Ok (moves, bailed)
  else
    match Effects.await ~timeout_ms:dig.frame_timeout_ms (fun _ -> true) with
    | Effects.Timeout -> Error "dig_wall_smart: timed out waiting for frame"
    | Effects.Holds m when Bdsp_readers.Dialog_detector.shown m ->
        log "Wall finished / collapsed dialog detected.";
        Ok (moves, bailed)
    | Effects.Holds m
      when moves >= min_moves_before_exit
           && not (Bdsp_readers.Mining_grid.on_mining_screen m) ->
        log "Mining wall screen ended; handing off to dig yield reader.";
        Ok (moves, bailed)
    | Effects.Holds m ->
        let next_bailed = step_dig ~log ~goal ~tally st ~moves ~bailed m in
        dig_loop ~log ~goal ~tally st (moves + 1) next_bailed

let dig_wall_smart ?announced_items ~log ~picture ~goal ~tally () =
  let module R = Bdsp_readers in
  ignore
    (Effects.subscribe
       (R.Dialog_detector.probes ~picture
       @ R.Mining_announce_reader.probes ~picture
       @ R.Mining_grid.probes ~picture)
      : string list);
  let announced_ref = ref announced_items in
  let* () = wait_wall_visible ~announced_ref () in
  let announced = Option.value !announced_ref ~default:dig.default_announced in
  log (Printf.sprintf "Starting smart dig (announced_items=%d)" announced);
  dig_loop ~log ~goal ~tally (make_dig_state ~announced_items:announced) 0 false

let collect_dig_yields = Dig_yields.collect
