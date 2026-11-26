module OW = Bdsp_actions.Bdsp_overworld
module US = Bdsp_readers.Underground_screen
module MS = Bdsp_readers.Minimap_sparkles
module WS = Bdsp_readers.Wall_sparkle
module P = Switch_home.Switch_presses
module D = Grid_geometry.Direction
module L = Grid_planning.Leg
open Bdsp_underground

let ( let* ) = Result.bind
let mech = Corridor_nav.bdsp_move_mechanics
let step_probe_timeout_ms = 350
let radar_hold_ms = 100
let radar_settle_ms = 450
let wall_margin_ms = 350
let wall_hug_ms = 450
let servo_step_ms = 240
let max_servo_steps = 4

let subscribe_screen ~picture =
  ignore (Effects.subscribe (US.probes ~picture) : string list)

let nav_dir_of_grid = function
  | D.North -> Corridor_nav.North
  | D.South -> Corridor_nav.South
  | D.East -> Corridor_nav.East
  | D.West -> Corridor_nav.West

let segment_of_corridor = function
  | MS.Bottom_east -> Ring_grid.Bottom_east
  | MS.East_vertical -> Ring_grid.East_vertical
  | MS.Top_east -> Ring_grid.Top_east

let execute_leg ~log (leg : _ L.t) =
  let dir = nav_dir_of_grid leg.direction in
  match leg.kind with
  | L.Face -> OW.turn dir
  | L.Special_step _ -> ()
  | L.Walk { tiles; to_wall } ->
      let per_tile =
        if D.is_across leg.direction then mech.run_across_ms
        else mech.run_up_down_ms
      in
      let base_ms = mech.start_delay_ms + (tiles * per_tile) in
      let hold_ms = if to_wall then base_ms + wall_margin_ms else base_ms in
      log
        (Printf.sprintf "Leg: %s %d tiles (to_wall=%b, %dms)"
           (D.name leg.direction) tiles to_wall hold_ms);
      OW.run_hold dir ~hold_ms

let handle_step ~picture ~on_prompt ~on_battle cur =
  match Effects.await ~timeout_ms:step_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m ->
      let scr = US.read m in
      if scr.battle then (
        let* next = on_battle cur in
        subscribe_screen ~picture;
        Ok (next, false))
      else if scr.dialog then (
        let* next, dug = on_prompt cur in
        subscribe_screen ~picture;
        Ok (next, dug))
      else Ok (cur, false)
  | Effects.Timeout -> Ok (cur, false)

let primary_wall_dir ~along_dir = function
  | d :: _ -> nav_dir_of_grid d
  | [] -> (
      match along_dir with
      | Corridor_nav.East | Corridor_nav.West -> Corridor_nav.North
      | Corridor_nav.North | Corridor_nav.South -> Corridor_nav.East)

let read_star_offset ~picture =
  subscribe_screen ~picture;
  match Effects.await ~timeout_ms:step_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m -> WS.locate m
  | Effects.Timeout -> None

let servo_step_toward ~along_dir (off : WS.offset) =
  match along_dir with
  | Corridor_nav.East | Corridor_nav.West ->
      if off.dx < 0 then Some Corridor_nav.West
      else if off.dx > 0 then Some Corridor_nav.East
      else None
  | Corridor_nav.North | Corridor_nav.South ->
      if off.dy < 0 then Some Corridor_nav.North
      else if off.dy > 0 then Some Corridor_nav.South
      else None

let wall_from_offset ~along_dir ~fallback (off : WS.offset) =
  match along_dir with
  | Corridor_nav.East | Corridor_nav.West ->
      if off.dy < 0 then Corridor_nav.North
      else if off.dy > 0 then Corridor_nav.South
      else fallback
  | Corridor_nav.North | Corridor_nav.South ->
      if off.dx > 0 then Corridor_nav.East
      else if off.dx < 0 then Corridor_nav.West
      else fallback

let rec lock_onto_star ~log ~picture ~along_dir ~fallback left =
  match read_star_offset ~picture with
  | None -> fallback
  | Some off -> (
      log (Printf.sprintf "Radar sparkle star at dx=%d dy=%d" off.dx off.dy);
      match (left > 0, servo_step_toward ~along_dir off) with
      | true, Some move_dir ->
          OW.run_hold move_dir ~hold_ms:servo_step_ms;
          lock_onto_star ~log ~picture ~along_dir ~fallback (left - 1)
      | _ -> wall_from_offset ~along_dir ~fallback off)

let interact_at_stop ~log ~picture ~on_prompt ~on_battle ~along_dir ~wall_dirs
    cur =
  subscribe_screen ~picture;
  P.press ~hold_ms:radar_hold_ms ~cooldown_ms:radar_settle_ms Wire.R;
  let fallback = primary_wall_dir ~along_dir wall_dirs in
  let face_dir =
    lock_onto_star ~log ~picture ~along_dir ~fallback max_servo_steps
  in
  OW.run_hold face_dir ~hold_ms:wall_hug_ms;
  OW.interact ();
  let* next, _dug = handle_step ~picture ~on_prompt ~on_battle cur in
  Ok next

let along_dir_of_legs = function
  | [] -> Corridor_nav.East
  | legs ->
      let last = List.hd (List.rev legs) in
      nav_dir_of_grid last.L.direction

let run_stop ~log ~picture ~on_prompt ~on_battle acc (st : Ring_grid.stop) =
  let* c = acc in
  log
    (Printf.sprintf "Route -> stop %s (%d legs)..."
       (Grid_geometry.Tile_pos.to_string st.tile)
       (List.length st.legs));
  List.iter (execute_leg ~log) st.legs;
  let along_dir = along_dir_of_legs st.legs in
  interact_at_stop ~log ~picture ~on_prompt ~on_battle ~along_dir
    ~wall_dirs:st.wall_dirs c

let visit_targets ~log ~picture ~start_door ~(sparkles : MS.nearby) ~on_prompt
    ~on_battle cur =
  let raw_waypoints =
    List.map
      (fun (t : MS.target) ->
        Ring_grid.waypoint_of_bucket
          ~segment:(segment_of_corridor t.corridor)
          ~bucket:t.bucket)
      sparkles.targets
  in
  let waypoints =
    if Grid_geometry.Tile_pos.equal start_door Ring_grid.north_door then
      List.rev raw_waypoints
    else raw_waypoints
  in
  let route = Ring_grid.plan_route ~start:start_door ~waypoints in
  log
    (Printf.sprintf "Planned tile route from %s: %d stop(s) -> return %s"
       (Grid_geometry.Tile_pos.to_string start_door)
       (List.length route.stops)
       (Grid_geometry.Tile_pos.to_string route.return_door));
  let* cur =
    List.fold_left
      (run_stop ~log ~picture ~on_prompt ~on_battle)
      (Ok cur) route.stops
  in
  log "Executing planned return legs to doorway...";
  List.iter (execute_leg ~log) route.return_legs;
  Ok (cur, route.return_door)
