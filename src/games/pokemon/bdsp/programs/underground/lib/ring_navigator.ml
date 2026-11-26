module OW = Bdsp_actions.Bdsp_overworld
module MS = Bdsp_readers.Minimap_sparkles
module D = Grid_geometry.Direction
module L = Grid_planning.Leg
open Bdsp_underground

let ( let* ) = Result.bind
let mech = Corridor_nav.bdsp_move_mechanics
let wall_margin_ms = 4500
let primary_wall_dir = Wall_lock.primary_wall_dir
let wall_from_offset = Wall_lock.wall_from_offset
let servo_step_toward = Wall_lock.servo_step_toward

let nav_dir_of_grid = function
  | D.North -> Corridor_nav.North
  | D.South -> Corridor_nav.South
  | D.East -> Corridor_nav.East
  | D.West -> Corridor_nav.West

let segment_of_corridor = function
  | MS.Bottom_east -> Ring_grid.Bottom_east
  | MS.East_vertical -> Ring_grid.East_vertical
  | MS.Top_east -> Ring_grid.Top_east

let execute_leg ~log ~brake_corner (leg : _ L.t) =
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
      let brake = to_wall || brake_corner in
      let hold_ms = if brake then base_ms + wall_margin_ms else base_ms in
      log
        (Printf.sprintf "Leg: %s %d tiles (to_wall=%b, %dms)"
           (D.name leg.direction) tiles brake hold_ms);
      OW.run_hold dir ~hold_ms

let rec execute_legs ~log ~dest_y = function
  | [] -> ()
  | [ last ] ->
      let brake_corner =
        last.L.direction = D.South && dest_y >= Ring_grid.south_door.y
      in
      execute_leg ~log ~brake_corner last
  | a :: (b :: _ as rest) ->
      let brake_corner = a.L.direction = D.South && b.L.direction = D.West in
      execute_leg ~log ~brake_corner a;
      execute_legs ~log ~dest_y rest

let along_dir_of_legs = function
  | [] -> Corridor_nav.East
  | legs ->
      let last = List.hd (List.rev legs) in
      nav_dir_of_grid last.L.direction

let run_stop ~log ~picture ~on_prompt ~on_battle ~re_seat acc
    (st : Ring_grid.stop) =
  let* c = acc in
  log
    (Printf.sprintf "Route -> stop %s (%d legs)..."
       (Grid_geometry.Tile_pos.to_string st.tile)
       (List.length st.legs));
  execute_legs ~log ~dest_y:st.tile.y st.legs;
  let along_dir = along_dir_of_legs st.legs in
  Wall_lock.interact_at_stop ~log ~picture ~on_prompt ~on_battle ~along_dir
    ~wall_dirs:st.wall_dirs ~tile:st.tile ~re_seat c

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
      (run_stop ~log ~picture ~on_prompt ~on_battle ~re_seat:true)
      (Ok cur) route.stops
  in
  log "Executing planned return legs to doorway...";
  execute_legs ~log ~dest_y:route.return_door.y route.return_legs;
  Ok (cur, route.return_door)

let first_stop_of ~start_door (sparkles : MS.nearby) =
  let ordered =
    if Grid_geometry.Tile_pos.equal start_door Ring_grid.north_door then
      List.rev sparkles.targets
    else sparkles.targets
  in
  match ordered with
  | [] -> None
  | first :: _ ->
      let wp =
        Ring_grid.waypoint_of_bucket
          ~segment:(segment_of_corridor first.corridor)
          ~bucket:first.bucket
      in
      let route = Ring_grid.plan_route ~start:start_door ~waypoints:[ wp ] in
      List.nth_opt route.stops 0

let route_to_first_stop ~log ~picture ~start_door ~sparkles ~on_prompt
    ~on_battle cur =
  match first_stop_of ~start_door sparkles with
  | None -> Ok cur
  | Some st ->
      run_stop ~log ~picture ~on_prompt ~on_battle ~re_seat:false (Ok cur) st
