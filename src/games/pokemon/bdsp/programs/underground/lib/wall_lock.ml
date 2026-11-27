module OW = Bdsp_actions.Bdsp_overworld
module US = Bdsp_readers.Underground_screen
module WS = Bdsp_readers.Wall_sparkle
module P = Switch_home.Switch_presses
module D = Grid_geometry.Direction
open Bdsp_underground

let ( let* ) = Result.bind
let mech = Corridor_nav.bdsp_move_mechanics

type radar_cfg = {
  probe_timeout_ms : int;
  hold_ms : int;
  settle_ms : int;
  retry_wait_ms : int;
  sample_tries : int;
}

type servo_cfg = {
  wall_hug_ms : int;
  align_step_ms : int;
  align_return_ms : int;
  screen_start_ms : int;
  tile_x_ms : int;
  tile_y_ms : int;
  tile_norm_x : float;
  tile_norm_y : float;
}

type reprobe_cfg = {
  max_direct_tiles : int;
  step_tiles : int;
  back_tiles : int;
  east_outer_x : int;
}

let radar =
  {
    probe_timeout_ms = 350;
    hold_ms = 100;
    settle_ms = 1600;
    retry_wait_ms = 300;
    sample_tries = 3;
  }

let servo =
  {
    wall_hug_ms = 900;
    align_step_ms = 240;
    align_return_ms = 520;
    screen_start_ms = 110;
    tile_x_ms = 130;
    tile_y_ms = 135;
    tile_norm_x = 0.085;
    tile_norm_y = 0.105;
  }

let reprobe =
  { max_direct_tiles = 5; step_tiles = 3; back_tiles = 6; east_outer_x = 14 }

let nav_dir_of_grid = function
  | D.North -> Corridor_nav.North
  | D.South -> Corridor_nav.South
  | D.East -> Corridor_nav.East
  | D.West -> Corridor_nav.West

let opposite_dir = function
  | Corridor_nav.North -> Corridor_nav.South
  | Corridor_nav.South -> Corridor_nav.North
  | Corridor_nav.East -> Corridor_nav.West
  | Corridor_nav.West -> Corridor_nav.East

let subscribe_screen ~picture =
  ignore (Effects.subscribe (US.probes ~picture) : string list)

let sample_frame ~picture =
  subscribe_screen ~picture;
  match Effects.await ~timeout_ms:radar.probe_timeout_ms (fun _ -> true) with
  | Effects.Holds m -> Some m
  | Effects.Timeout -> None

let handle_step ~picture ~on_prompt ~on_battle cur =
  match Effects.await ~timeout_ms:radar.probe_timeout_ms (fun _ -> true) with
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

let non_south_walls wall_dirs = List.filter (fun d -> d <> D.South) wall_dirs

let primary_wall_dir ~along_dir wall_dirs =
  let valid = non_south_walls wall_dirs in
  match along_dir with
  | Corridor_nav.East | Corridor_nav.West -> (
      if List.mem D.North valid then Corridor_nav.North
      else
        match valid with
        | d :: _ -> nav_dir_of_grid d
        | [] -> Corridor_nav.North)
  | Corridor_nav.North | Corridor_nav.South -> (
      match valid with d :: _ -> nav_dir_of_grid d | [] -> Corridor_nav.East)

let wall_from_offset ~along_dir ~wall_dirs ~fallback (off : WS.offset) =
  let valid = non_south_walls wall_dirs in
  match along_dir with
  | Corridor_nav.East | Corridor_nav.West ->
      if off.dy < 0 && List.mem D.North valid then Corridor_nav.North
      else if off.dx > 0 && List.mem D.East valid then Corridor_nav.East
      else if off.dx < 0 && List.mem D.West valid then Corridor_nav.West
      else fallback
  | Corridor_nav.North | Corridor_nav.South ->
      if off.dx > 0 && List.mem D.East valid then Corridor_nav.East
      else if off.dx < 0 && List.mem D.West valid then Corridor_nav.West
      else fallback

let servo_step_toward ~face_dir (off : WS.offset) =
  match face_dir with
  | Corridor_nav.North | Corridor_nav.South ->
      if off.dx < 0 then Some Corridor_nav.West
      else if off.dx > 0 then Some Corridor_nav.East
      else None
  | Corridor_nav.East | Corridor_nav.West ->
      if off.dy < 0 then Some Corridor_nav.North
      else if off.dy > 0 then Some Corridor_nav.South
      else None

let servo_hold_ms ~face_dir (off : WS.offset) =
  let dist, tile_norm, per_tile =
    match face_dir with
    | Corridor_nav.North | Corridor_nav.South ->
        (Float.abs off.dx_norm, servo.tile_norm_x, servo.tile_x_ms)
    | Corridor_nav.East | Corridor_nav.West ->
        (Float.abs off.dy_norm, servo.tile_norm_y, servo.tile_y_ms)
  in
  let tiles =
    max 1
      (min reprobe.max_direct_tiles
         (int_of_float (Float.round (dist /. tile_norm))))
  in
  servo.screen_start_ms + (tiles * per_tile)

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
        P.wait radar.retry_wait_ms;
        poll (tries_left - 1)
    | None -> None
  in
  poll radar.sample_tries

let move_to_star ~face_dir off =
  match servo_step_toward ~face_dir off with
  | None -> ()
  | Some move_dir -> OW.run_hold move_dir ~hold_ms:(servo_hold_ms ~face_dir off)

(* Move directly to the diff-verified sparkle star in one proportional step
   (never re-running a torch-blind [before=None] read that could lock onto a
   static wall torch and walk away from the star). *)
let lock_onto_star ~log ~picture ~along_dir ~wall_dirs ~fallback ~before =
  match read_star_offset ~picture ~before with
  | None -> (fallback, false)
  | Some off ->
      log
        (Printf.sprintf "Radar sparkle star at dx=%d dy=%d (%.2f, %.2f)" off.dx
           off.dy off.dx_norm off.dy_norm);
      let face_dir = wall_from_offset ~along_dir ~wall_dirs ~fallback off in
      move_to_star ~face_dir off;
      (face_dir, true)

let lateral_dirs = function
  | Corridor_nav.North | Corridor_nav.South ->
      (Corridor_nav.West, Corridor_nav.East)
  | Corridor_nav.East | Corridor_nav.West ->
      (Corridor_nav.North, Corridor_nav.South)

let try_wall_interact ~picture ~on_prompt ~on_battle ~face_dir cur =
  OW.run_hold face_dir ~hold_ms:servo.wall_hug_ms;
  OW.interact ();
  handle_step ~picture ~on_prompt ~on_battle cur

let try_lateral_steps ~picture ~on_prompt ~on_battle ~face_dir cur steps =
  let rec loop c = function
    | [] -> Ok c
    | (dir, hold_ms) :: rest ->
        OW.run_hold dir ~hold_ms;
        let* next, dug =
          try_wall_interact ~picture ~on_prompt ~on_battle ~face_dir c
        in
        if dug then Ok next else loop next rest
  in
  loop cur steps

let align_and_interact ~picture ~on_prompt ~on_battle ~face_dir ~saw_star cur =
  let* cur, dug =
    try_wall_interact ~picture ~on_prompt ~on_battle ~face_dir cur
  in
  if dug || not saw_star then Ok cur
  else
    let d_neg, d_pos = lateral_dirs face_dir in
    try_lateral_steps ~picture ~on_prompt ~on_battle ~face_dir cur
      [
        (d_neg, servo.align_step_ms);
        (d_neg, servo.align_step_ms);
        (d_pos, servo.align_return_ms);
        (d_pos, servo.align_step_ms);
      ]

let outer_wall_of_tile (p : Grid_geometry.Tile_pos.t) =
  if p.x >= reprobe.east_outer_x then Corridor_nav.East else Corridor_nav.North

let pulse_and_lock ~log ~picture ~along_dir ~wall_dirs ~fallback =
  let before = sample_frame ~picture in
  P.press ~hold_ms:radar.hold_ms ~cooldown_ms:radar.settle_ms Wire.R;
  lock_onto_star ~log ~picture ~along_dir ~wall_dirs ~fallback ~before

let shift_corridor dir tiles =
  let per_tile =
    match dir with
    | Corridor_nav.East | Corridor_nav.West -> mech.run_across_ms
    | Corridor_nav.North | Corridor_nav.South -> mech.run_up_down_ms
  in
  OW.run_hold dir ~hold_ms:(mech.start_delay_ms + (tiles * per_tile))

let reprobe_back ~log ~picture ~along_dir ~wall_dirs ~fallback =
  log "Still no star; re-probing -3 tiles...";
  shift_corridor (opposite_dir along_dir) reprobe.back_tiles;
  match pulse_and_lock ~log ~picture ~along_dir ~wall_dirs ~fallback with
  | (_, true) as hit -> hit
  | res ->
      shift_corridor along_dir reprobe.step_tiles;
      res

let find_star_with_reprobe ~log ~picture ~along_dir ~wall_dirs ~fallback =
  match pulse_and_lock ~log ~picture ~along_dir ~wall_dirs ~fallback with
  | (_, true) as hit -> hit
  | _ -> (
      log "No star at stop; re-probing +3 tiles...";
      shift_corridor along_dir reprobe.step_tiles;
      match pulse_and_lock ~log ~picture ~along_dir ~wall_dirs ~fallback with
      | (_, true) as hit -> hit
      | _ -> reprobe_back ~log ~picture ~along_dir ~wall_dirs ~fallback)

let interact_at_stop ~log ~picture ~on_prompt ~on_battle ~along_dir ~wall_dirs
    ~tile ~re_seat cur =
  let fallback = primary_wall_dir ~along_dir wall_dirs in
  let face_dir, saw_star =
    find_star_with_reprobe ~log ~picture ~along_dir ~wall_dirs ~fallback
  in
  let* next =
    align_and_interact ~picture ~on_prompt ~on_battle ~face_dir ~saw_star cur
  in
  if re_seat then
    OW.run_hold (outer_wall_of_tile tile) ~hold_ms:servo.wall_hug_ms;
  Ok next
