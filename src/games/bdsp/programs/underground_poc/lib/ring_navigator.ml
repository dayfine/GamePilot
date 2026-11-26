module OW = Bdsp_actions.Bdsp_overworld
module US = Bdsp_readers.Underground_screen
module MS = Bdsp_readers.Minimap_sparkles
module P = Switch_home.Switch_presses
module D = Grid_geometry.Direction
module L = Grid_planning.Leg
open Bdsp_underground

let ( let* ) = Result.bind
let mech = Corridor_nav.bdsp_move_mechanics
let step_probe_timeout_ms = 350
let wall_margin_ms = 350
let wall_hug_ms = 450
let probe_tiles_around_stop = 4

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

let probe_stop_walls ~picture ~on_prompt ~on_battle ~along_dir ~wall_dirs cur =
  subscribe_screen ~picture;
  let face_dir = primary_wall_dir ~along_dir wall_dirs in
  OW.run_hold face_dir ~hold_ms:wall_hug_ms;
  let rec loop left acc =
    if left <= 0 then Ok acc
    else (
      OW.turn face_dir;
      OW.interact ();
      let* next, dug = handle_step ~picture ~on_prompt ~on_battle acc in
      if dug then Ok next
      else (
        OW.step_tap along_dir 1;
        loop (left - 1) next))
  in
  loop probe_tiles_around_stop cur

let along_dir_of_legs = function
  | [] -> Corridor_nav.East
  | legs ->
      let last = List.hd (List.rev legs) in
      nav_dir_of_grid last.L.direction

let run_stop ~log ~picture ~on_prompt ~on_battle acc (st : Ring_grid.stop) =
  let* c = acc in
  log
    (Printf.sprintf "Walking to stop %s (%d legs)..."
       (Grid_geometry.Tile_pos.to_string st.tile)
       (List.length st.legs));
  List.iter (execute_leg ~log) st.legs;
  let along_dir = along_dir_of_legs st.legs in
  probe_stop_walls ~picture ~on_prompt ~on_battle ~along_dir
    ~wall_dirs:st.wall_dirs c

let visit_targets ~log ~picture ~(sparkles : MS.nearby) ~on_prompt ~on_battle
    cur =
  let waypoints =
    List.map
      (fun (t : MS.target) ->
        Ring_grid.waypoint_of_bucket
          ~segment:(segment_of_corridor t.corridor)
          ~bucket:t.bucket)
      sparkles.targets
  in
  let route = Ring_grid.plan_route ~start:Ring_grid.south_door ~waypoints in
  log
    (Printf.sprintf "Planned tile route: %d stop(s) -> return %s"
       (List.length route.stops)
       (Grid_geometry.Tile_pos.to_string route.return_door));
  let* cur =
    List.fold_left
      (run_stop ~log ~picture ~on_prompt ~on_battle)
      (Ok cur) route.stops
  in
  log "Executing planned return legs to doorway...";
  List.iter (execute_leg ~log) route.return_legs;
  Ok cur
