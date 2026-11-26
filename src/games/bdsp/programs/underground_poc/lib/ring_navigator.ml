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
let radar_settle_ms = 850
let radar_retry_wait_ms = 300
let radar_sample_tries = 3
let wall_margin_ms = 1500
let wall_hug_ms = 1100
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

let primary_wall_dir ~along_dir wall_dirs =
  match along_dir with
  | Corridor_nav.East | Corridor_nav.West -> Corridor_nav.North
  | Corridor_nav.North | Corridor_nav.South -> (
      match List.filter (fun d -> d <> D.South) wall_dirs with
      | d :: _ -> nav_dir_of_grid d
      | [] -> Corridor_nav.East)

let sample_frame ~picture =
  subscribe_screen ~picture;
  match Effects.await ~timeout_ms:step_probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m -> Some m
  | Effects.Timeout -> None

let read_star_offset ~picture ~before =
  let locate_from after =
    match before with
    | Some b -> WS.locate_diff ~before:b ~after
    | None -> WS.locate after
  in
  let rec poll tries_left =
    match Option.bind (sample_frame ~picture) locate_from with
    | Some _ as hit -> hit
    | None when tries_left > 1 ->
        P.wait radar_retry_wait_ms;
        poll (tries_left - 1)
    | None -> None
  in
  poll radar_sample_tries

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

(* Dig spots never spawn on the South cutaway rim; horizontal corridors face
   North unless the star sits on an adjacent East/West corner wall, while
   vertical corridors face East or West from the star offset. *)
let wall_from_offset ~along_dir ~wall_dirs ~fallback (off : WS.offset) =
  match along_dir with
  | Corridor_nav.East | Corridor_nav.West ->
      if off.dy < 0 then Corridor_nav.North
      else if off.dx > 0 && List.mem D.East wall_dirs then Corridor_nav.East
      else if off.dx < 0 && List.mem D.West wall_dirs then Corridor_nav.West
      else Corridor_nav.North
  | Corridor_nav.North | Corridor_nav.South ->
      if off.dx > 0 then Corridor_nav.East
      else if off.dx < 0 then Corridor_nav.West
      else fallback

let rec lock_onto_star ~log ~picture ~along_dir ~wall_dirs ~fallback ~before
    ~seen left =
  match read_star_offset ~picture ~before with
  | None -> seen
  | Some off ->
      log (Printf.sprintf "Radar sparkle star at dx=%d dy=%d" off.dx off.dy);
      let face_dir = wall_from_offset ~along_dir ~wall_dirs ~fallback off in
      step_or_face ~log ~picture ~along_dir ~wall_dirs ~fallback ~face_dir left
        off

and step_or_face ~log ~picture ~along_dir ~wall_dirs ~fallback ~face_dir left
    off =
  match (left > 0, servo_step_toward ~along_dir off) with
  | true, Some move_dir ->
      OW.run_hold move_dir ~hold_ms:servo_step_ms;
      lock_onto_star ~log ~picture ~along_dir ~wall_dirs ~fallback ~before:None
        ~seen:(face_dir, true) (left - 1)
  | _ -> (face_dir, true)

let lateral_dirs = function
  | Corridor_nav.North | Corridor_nav.South ->
      (Corridor_nav.West, Corridor_nav.East)
  | Corridor_nav.East | Corridor_nav.West ->
      (Corridor_nav.North, Corridor_nav.South)

let try_wall_interact ~picture ~on_prompt ~on_battle ~face_dir cur =
  OW.run_hold face_dir ~hold_ms:wall_hug_ms;
  OW.interact ();
  handle_step ~picture ~on_prompt ~on_battle cur

let align_and_interact ~picture ~on_prompt ~on_battle ~face_dir ~saw_star cur =
  let* cur, dug =
    try_wall_interact ~picture ~on_prompt ~on_battle ~face_dir cur
  in
  if dug || not saw_star then Ok cur
  else
    let d_neg, d_pos = lateral_dirs face_dir in
    OW.run_hold d_neg ~hold_ms:servo_step_ms;
    let* cur, dug =
      try_wall_interact ~picture ~on_prompt ~on_battle ~face_dir cur
    in
    if dug then Ok cur
    else (
      OW.run_hold d_pos ~hold_ms:(servo_step_ms * 2);
      let* cur, _ =
        try_wall_interact ~picture ~on_prompt ~on_battle ~face_dir cur
      in
      Ok cur)

let east_outer_x = 14

let outer_wall_of_tile (p : Grid_geometry.Tile_pos.t) =
  if p.x >= east_outer_x then Corridor_nav.East else Corridor_nav.North

let interact_at_stop ~log ~picture ~on_prompt ~on_battle ~along_dir ~wall_dirs
    ~tile ~re_seat cur =
  let before = sample_frame ~picture in
  P.press ~hold_ms:radar_hold_ms ~cooldown_ms:radar_settle_ms Wire.R;
  let fallback = primary_wall_dir ~along_dir wall_dirs in
  let face_dir, saw_star =
    lock_onto_star ~log ~picture ~along_dir ~wall_dirs ~fallback ~before
      ~seen:(fallback, false) max_servo_steps
  in
  let* next =
    align_and_interact ~picture ~on_prompt ~on_battle ~face_dir ~saw_star cur
  in
  if re_seat then OW.run_hold (outer_wall_of_tile tile) ~hold_ms:wall_hug_ms;
  Ok next

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
  List.iter (execute_leg ~log) st.legs;
  let along_dir = along_dir_of_legs st.legs in
  interact_at_stop ~log ~picture ~on_prompt ~on_battle ~along_dir
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
  List.iter (execute_leg ~log) route.return_legs;
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
