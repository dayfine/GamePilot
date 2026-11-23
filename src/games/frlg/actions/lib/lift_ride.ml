open Frlg_readers
module D = Grid_maps.Direction
module M = Menu_input

type lift = Rocket_hideout | Dept_store
type ride = { lift : lift; from : int; to_ : int }

let menu = function
  | Rocket_hideout -> [ "B1F"; "B2F"; "B4F"; "EXIT" ]
  | Dept_store -> [ "5F"; "4F"; "3F"; "2F"; "1F"; "EXIT" ]

let below_door map (tile : Grid_maps.Tile_pos.t) : Story.Pose.grid =
  { map; tiles = [ tile ]; facing = Some D.South }

(* RocketHideout_Elevator's setdynamicwarp lands on each floor's lift door,
   B1F (24, 25), B2F (28, 16), B4F (20, 23); the store's on (6, 1) of every
   floor. The game walks the player a tile south off it. *)
let hideout_exits =
  [
    below_door "RocketHideout_B1F" { x = 24; y = 26 };
    below_door "RocketHideout_B2F" { x = 28; y = 17 };
    below_door "RocketHideout_B4F" { x = 20; y = 24 };
  ]

let store_floor floor =
  below_door ("CeladonCity_DepartmentStore_" ^ floor) { x = 6; y = 2 }

let exits = function
  | Rocket_hideout -> hideout_exits
  | Dept_store -> List.map store_floor [ "5F"; "4F"; "3F"; "2F"; "1F" ]

(* The row of [floor] on the lift's menu, if it is a floor (not EXIT). *)
let floor_row lift floor =
  let rows = menu lift in
  let floors = List.filteri (fun i _ -> i + 1 < List.length rows) rows in
  List.find_index (String.equal floor) floors

let ride_of_floors ~from ~to_ =
  List.find_map
    (fun lift ->
      match (floor_row lift from, floor_row lift to_) with
      | Some from, Some to_ -> Some { lift; from; to_ }
      | _ -> None)
    [ Rocket_hideout; Dept_store ]

let where = "lift_floor: "

let ride_of_args args =
  let bad e = Error (Story.Failure.cause ~repeats:true "bad_args" e) in
  match
    ( Grid_maps.Json_field.string ~where "from" args,
      Grid_maps.Json_field.string ~where "to" args )
  with
  | exception Grid_maps.Json_field.Invalid e -> bad e
  | from, to_ -> (
      match ride_of_floors ~from ~to_ with
      | Some ride -> Ok ride
      | None ->
          bad (Printf.sprintf "%sno lift has both %s and %s" where from to_))

type presses = { direction : D.t; count : int }

(* Up to three rows a multichoice does not wrap. *)
let max_rows_without_wrap = 3

let menu_presses ride =
  let entries = List.length (menu ride.lift) in
  let down = (ride.to_ + entries - ride.from) mod entries in
  let up = (ride.from + entries - ride.to_) mod entries in
  if entries <= max_rows_without_wrap then
    if ride.to_ >= ride.from then
      { direction = D.South; count = ride.to_ - ride.from }
    else { direction = D.North; count = ride.from - ride.to_ }
  else if down <= up then { direction = D.South; count = down }
  else { direction = D.North; count = up }

let arrival ride : Story.Pose.observed =
  let exit = List.nth (exits ride.lift) ride.to_ in
  { at_map = exit.map; at_tile = List.hd exit.tiles; faces = exit.facing }

(* A straight piece of the lift's script, as the fork's RoomLeg: [tiles]
   steps, a step tap a tile; none: a turn to face [direction]. [warp]: how the
   leg's last step's warp shows. *)
type warp = No_warp | Fade | Dim
type leg = { direction : D.t; tiles : int; warp : warp }

let leg ?(warp = No_warp) direction tiles = { direction; tiles; warp }

(* From below the floor's lift door (facing north) through it onto the lift's
   arrival tile (2, 5), up to below the panel at (0, 3), facing it. *)
let lift_in_legs =
  [ leg ~warp:Fade D.North 1; leg D.North 2; leg D.West 2; leg D.North 0 ]

(* From below the panel, into the west wall, down and back to the arrival
   tile, and south off it: the floor picked. *)
let lift_out_legs =
  [ leg D.West 4; leg D.South 2; leg D.East 2; leg ~warp:Dim D.South 1 ]

(* As the fork's: a message and its menu take this long to show on fast text,
   before the menu takes the D-pad (LIFT_MENU_WAIT, not measured). *)
let lift_menu_wait_ms = 1500

(* After A on the floor (pbf_press_button(A, 160ms, 800ms)). *)
let floor_pick_wait_ms = 800

(* The fork's WARP_TIMEOUT: a warp's fade, or a dim warp's scene, shows. *)
let warp_timeout_ms = 8000
let fade_up_timeout_ms = 5000

(* From a black fade's end until the room is in full light (WARP_FADE_IN). *)
let warp_fade_in_ms = 300

(* Between looks at a dim warp's scene (DIM_WARP_POLL). *)
let dim_poll_ms = 150
let dim_warp_change = 30.0
let tap = Grid_maps.Move_mechanics.frlg.walk.tap

let step_tap direction =
  M.hold ~hold_ms:tap.hold_ms ~cooldown_ms:tap.release_ms (M.dpad direction)

let faded m = (Screen_facts.of_measurements m).fade <> Screen_state.Fade.No_fade

let middle m =
  Option.map
    (fun (s : Solid_color.stats) -> s.mean)
    (Solid_color.read m Screen_facts.fade_id)

let moved (a : Wire.rgb) (b : Wire.rgb) =
  Float.abs (a.r -. b.r) +. Float.abs (a.g -. b.g) +. Float.abs (a.b -. b.b)

(* The last step onto a black-fade warp: the fade is watched from the tap on,
   since it can be over before a wait started after it looks. *)
let step_into_fade direction =
  (match Effects.race [ step_tap direction ] ~stop:faded with
  | Stopped _ -> ()
  | Finished _ ->
      ignore
        (M.await_screen ~timeout_ms:warp_timeout_ms ~code:"no_warp_fade"
           "the lift door's fade" faded));
  ignore
    (M.await_screen ~timeout_ms:fade_up_timeout_ms ~code:"fade_stuck"
       "the room after the fade" (fun m -> not (faded m)));
  ignore (Effects.submit [ Wire.Wait { wait_ms = warp_fade_in_ms } ])

(* One look at a dim warp's scene: whether the middle of the screen has left
   [before] and held still since [last], the look before if it had left too. *)
let dim_look before last now =
  let left = moved before now >= dim_warp_change in
  let still =
    Option.fold ~none:false
      ~some:(fun l -> moved l now < Scene_looks.max_still_change)
      !last
  in
  last := if left then Some now else None;
  left && still

(* A dim warp's end (the fork's wait_out_dim_warp()): looked at every
   [dim_poll_ms], the middle of the screen has left [before] and holds still
   since the look before. *)
let dim_scene_over before =
  let last = ref None and last_ms = ref neg_infinity in
  fun (m : Effects.measurements) ->
    let due = m.t_ms -. !last_ms >= float_of_int dim_poll_ms in
    if due then last_ms := m.t_ms;
    due && Option.fold ~none:false ~some:(dim_look before last) (middle m)

let wait_out_dim before =
  match before with
  | None ->
      M.fail "lift_scene_stuck" "no screen before the step out of the lift"
  | Some before ->
      ignore
        (M.await_screen ~timeout_ms:warp_timeout_ms ~code:"lift_scene_stuck"
           "a still scene after the lift" (dim_scene_over before))

let walk_leg ~log facing { direction; tiles; warp } =
  if tiles = 0 || !facing <> direction then
    ignore (Effects.submit (Frlg_overworld.Route_legs.turn_tap direction));
  facing := direction;
  let before = Option.bind (Effects.read ()) middle in
  for tile = 1 to tiles do
    if tile = tiles && warp = Fade then step_into_fade direction
    else ignore (Effects.submit [ step_tap direction ])
  done;
  if warp = Dim then (
    wait_out_dim before;
    log "Lift: the dim fade out of the lift is over.")

let pick_floor ~log ride =
  let rows = Array.of_list (menu ride.lift) in
  let { direction; count } = menu_presses ride in
  log
    (Printf.sprintf "Story: lift from %s to %s: %d press(es) %s."
       rows.(ride.from) rows.(ride.to_) count (D.name direction));
  M.press Wire.A ~cooldown_ms:lift_menu_wait_ms;
  M.taps (M.dpad direction) count;
  M.press Wire.A ~cooldown_ms:floor_pick_wait_ms;
  (* B during the ride does nothing; the menu took the A. *)
  M.settle_back ~label:"lift ride" ~log

let ride ~log ride =
  let facing = ref D.North in
  List.iter (walk_leg ~log facing) lift_in_legs;
  pick_floor ~log ride;
  facing := D.North;
  List.iter (walk_leg ~log facing) lift_out_legs
