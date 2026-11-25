open Grid_maps

type gait = Walking | Running

type move =
  | Hold of {
      spec : Grid_walker.Leg_spec.t;
      running : bool;
      warps : bool;
      wild : bool;
      turn_first : bool;
    }
  | Turn of Direction.t

let mechanics = Move_mechanics.frlg

(* The release between a hold and what comes next (STEP_RELEASE). *)
let step_release_ms = 100

(* After a turn tap, the turn showing (TURN_SETTLE). *)
let turn_settle_ms = 300

let dpad = function
  | Direction.North -> Wire.Up
  | East -> Right
  | South -> Down
  | West -> Left

let mover ~running direction hold_ms =
  let buttons =
    if running then [ dpad direction; Wire.B ] else [ dpad direction ]
  in
  [ Wire.press ~hold_ms ~cooldown_ms:step_release_ms buttons ]

let turn_tap direction =
  [
    Wire.press ~hold_ms:mechanics.turn_tap_ms ~cooldown_ms:turn_settle_ms
      [ dpad direction ];
  ]

(* A step onto another map stalls, where the world's edges stall. *)
let stalls (w : Frlg_steps.world) (step : _ Grid_planning.Leg.step) =
  step.connection && w.edge_stalls

(* The step numbers (from 1) of a press's tiles that stall and that are slow:
   a step onto another map may stall, a step on rock stairs is slow. *)
let marks w place d (step : _ Grid_planning.Leg.step) tiles (stalled, slow) =
  ( (if stalls w step then tiles :: stalled else stalled),
    if Frlg_steps.slow_step w place d step.next then tiles :: slow else slow )

(* The tiles' time and the stalled and slow steps of [presses] presses from
   the leg's start: a hop is two tiles. *)
let walked_tiles w (leg : Connected_maps.place Grid_planning.Leg.t) presses =
  let d = leg.direction in
  let rec go place i tiles ((stalled, slow) as marked) =
    let finish extra = (tiles + extra, List.rev stalled, List.rev slow) in
    if i > presses then finish 0
    else
      match Frlg_steps.press w place d with
      | None -> finish (presses - i + 1)
      | Some step ->
          let tiles = tiles + Frlg_steps.hop_tiles w place d in
          go step.next (i + 1) tiles (marks w place d step tiles marked)
  in
  go leg.start 1 0 ([], [])

let off_exit_mat (w : Frlg_steps.world) (place : Connected_maps.place) d =
  match Map_data.warp_at (Connected_maps.map w.maps place.map) place.tile with
  | Some { enter = Walk way; _ } -> way = d
  | _ -> false

let hold w gait ~facing (leg : Connected_maps.place Grid_planning.Leg.t) presses
    to_wall =
  let map = Connected_maps.map w.Frlg_steps.maps leg.start.map in
  let running = gait = Running && map.allow_running in
  let gait = if running then mechanics.run else mechanics.walk in
  let tiles, stalled_steps, slow_steps = walked_tiles w leg presses in
  let spec =
    Grid_walker.Leg_spec.make ~to_wall
      ~tile_ms:(Move_mechanics.along gait.tile leg.direction)
      leg.direction tiles
  in
  Hold
    {
      spec =
        {
          spec with
          stalled_steps;
          slow_steps;
          slow_step_ms = gait.slow_step_ms;
        };
      running;
      warps = leg.warps;
      wild = leg.wild;
      turn_first =
        facing <> Some leg.direction
        && not (off_exit_mat w leg.start leg.direction);
    }

let move_of w gait ~facing (leg : Connected_maps.place Grid_planning.Leg.t) =
  match leg.kind with
  | Walk { tiles; to_wall } -> Ok (hold w gait ~facing leg tiles to_wall)
  | Face -> Ok (Turn leg.direction)
  | Action _ ->
      Error
        (Printf.sprintf "an action leg %s is not walked yet"
           (Direction.name leg.direction))
