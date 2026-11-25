open Grid_maps
open Grid_geometry

type t = {
  world : Frlg_steps.world;
  gait : Route_legs.gait;
  flee : unit -> unit;
  log : string -> unit;
}

type at = { place : Connected_maps.place; facing : Direction.t option }

let warp_fade_timeout_ms = 3000
let fade_up_timeout_ms = 5000
let after_leg_watch_ms = 500
let after_wild_leg_watch_ms = 3500

(* From a warp's fade coming up to the player taking input, when the game walks
   them out of a doorway: the door opens, then a walking tile. On mGBA the
   step ended 40 frames (667ms) after the fade read as up, and a turn and a
   hold sent sooner lost 4 tiles of "east 6" (2026-11-23, mg-04 out of
   Lavender Town's Center); the fork waits 1500ms after every warp. *)
let door_step_out_ms = 1000

(* Times a walk goes on before a sign the plan did not walk into. *)
let max_sign_rejoins = 2

exception Walk_failed of Pokemon_checkpoints.Failure.cause
exception Leg_blocked

let fail code fmt =
  Printf.ksprintf
    (fun s -> raise (Walk_failed (Pokemon_checkpoints.Failure.cause code s)))
    fmt

let faded m =
  (Frlg_readers.Screen_facts.of_measurements m).fade
  <> Screen_state.Fade.No_fade

let fade_up () =
  match
    Effects.await ~timeout_ms:fade_up_timeout_ms (fun m -> not (faded m))
  with
  | Holds m -> m
  | Timeout -> fail "fade_stuck" "the warp's fade did not come back up"

(* From the fade's first lit frame [lit] until the room stands still in full
   light ({!Warp_fade_in}). A screen never still by the timeout is long past
   any fade-in: the walk goes on. *)
let wait_fade_in t lit =
  let fade_in = Warp_fade_in.create lit in
  match
    Effects.await ~timeout_ms:fade_up_timeout_ms (Warp_fade_in.seen fade_in)
  with
  | Holds _ -> ()
  | Timeout -> t.log "Route: the screen never stood still after the warp."

(* A map preview's fades: a flash of white, then black, then the map; each
   watched for [watch_ms] from the one before coming up at [lit]. The last
   fade's first lit frame. *)
let rec wait_out_preview lit ~watch_ms =
  match Effects.await ~timeout_ms:watch_ms faded with
  | Holds _ -> wait_out_preview (fade_up ()) ~watch_ms:Map_previews.fade_gap_ms
  | Timeout -> lit

(* After a warp: its fade, a map preview's fade if one shows, the fade-in and
   the step out of a doorway, until the player takes input. The step out is
   timed from the fade's first lit frame. *)
let wait_out_warp t fade ~preview ~steps_out =
  (if not (Grid_walker.Watch_along.fired fade) then
     match Effects.await ~timeout_ms:warp_fade_timeout_ms faded with
     | Holds _ -> ()
     | Timeout -> fail "no_warp_fade" "no fade after the hold onto the warp");
  let lit = fade_up () in
  wait_fade_in t
    (if preview then wait_out_preview lit ~watch_ms:Map_previews.watch_ms
     else lit);
  if steps_out then
    let left_ms = lit.t_ms +. float_of_int door_step_out_ms -. Effects.now () in
    if left_ms > 0. then
      ignore
        (Effects.await ~timeout_ms:(int_of_float left_ms) (fun _ -> false)
          : Effects.awaited)

let map_name t (place : Connected_maps.place) =
  (Connected_maps.map t.world.maps place.map).name

(* A hold on a leg with wild battles goes on watching after its release, so a
   battle set off by its last steps is timed from the hold's start: the walk
   learns how far it got (run 4 of mg-04, 2026-11-23: a battle on the second
   tile of "south 3" flashed as the hold ended and was taken for one at the
   leg's end, so the walk went on a tile short). *)
let mover ~running ~wild direction hold_ms =
  Route_legs.mover ~running direction hold_ms
  @
  if wild then [ Wire.Wait { wait_ms = Walk_interrupts.flash_watch_ms } ]
  else []

let walker t ~running ~wild : Grid_walker.Leg_walker.t =
  {
    mover = mover ~running ~wild;
    interrupts = Walk_interrupts.for_leg ~flee:t.flee ~wild;
    log = t.log;
    tracer = None;
  }

(* Holds a leg; raises [Leg_blocked] when something on the way, like a sign,
   interrupted hold after hold. *)
let hold t (leg : Connected_maps.place Grid_planning.Leg.t)
    (spec : Grid_walker.Leg_spec.t) ~running ~wild ~turn_first =
  if turn_first then
    ignore (Effects.submit (Route_legs.turn_tap spec.direction));
  let walker = walker t ~running ~wild in
  let fade = Grid_walker.Watch_along.create faded in
  let hold_watchers = if leg.warps then [ fade ] else [] in
  let spec = { spec with stop_if_blocked = true } in
  let result = Grid_walker.Leg_walker.walk_leg ~hold_watchers walker spec in
  if result.stopped then raise Leg_blocked;
  if leg.warps then
    wait_out_warp t fade
      ~preview:
        (Map_previews.on_warp ~from_map:(map_name t leg.start)
           ~to_map:(map_name t leg.finish))
      ~steps_out:(Frlg_steps.walked_out_onto t.world leg.finish);
  let watch_ms = if wild then after_wild_leg_watch_ms else after_leg_watch_ms in
  ignore (Grid_walker.Leg_walker.clear_late_interrupts walker ~watch_ms : int)

let walk_one t at (leg : Connected_maps.place Grid_planning.Leg.t) =
  (match Route_legs.move_of t.world t.gait ~facing:at.facing leg with
  | Error e -> fail "route_unsupported" "%s" e
  | Ok (Turn d) ->
      if at.facing <> Some d then
        ignore (Effects.submit (Route_legs.turn_tap d))
  | Ok (Hold { spec; running; warps = _; wild; turn_first }) ->
      t.log ("Route: " ^ Grid_walker.Leg_spec.to_string spec);
      hold t leg spec ~running ~wild ~turn_first);
  { place = leg.finish; facing = Some leg.facing_after }

let last_leg legs = List.nth legs (List.length legs - 1)

(* The legs from [place], facing [facing], to where [legs] end. *)
let replan t place facing (legs : Connected_maps.place Grid_planning.Leg.t list)
    =
  let goal = last_leg legs in
  Grid_planning.Leg_planner.plan (Frlg_steps.model t.world) ~start:place
    ~start_facing:(Some facing)
    ~at_goal:(fun p -> Connected_maps.compare_place p goal.finish = 0)
    ~goal_facing:(Some goal.facing_after)

let blocked_failure (leg : Connected_maps.place Grid_planning.Leg.t) why =
  fail "leg_blocked" "%s: a message at every hold; %s"
    (Direction.name leg.direction)
    why

(* After [leg] was blocked: the legs on from the one sign on the maps that
   explains it, as the fork's after_blocked(). *)
let rejoin t ~before (leg : Connected_maps.place Grid_planning.Leg.t) legs =
  let starts = Before_signs.possible_starts ~before leg in
  match Before_signs.stops t.world starts leg with
  | [ stop ] -> (
      t.log
        (Printf.sprintf "Route: a sign ahead speaks at every hold; on from %s."
           (Tile_pos.to_string stop.tile));
      match replan t stop leg.direction legs with
      | Some legs -> ({ place = stop; facing = Some leg.direction }, legs)
      | None -> blocked_failure leg "no walk on from the sign")
  | [] -> blocked_failure leg "no sign on the maps is ahead: off the route"
  | _ -> blocked_failure leg "more than one sign could be ahead"

(* The legs [legs] walked from [at]: [Ok] where they end, or [Error] where a
   sign leaves the player and the legs on from there. *)
let rec walk_on t ~before at legs =
  match legs with
  | [] -> Ok at
  | leg :: rest -> (
      match walk_one t at leg with
      | next -> walk_on t ~before:(Some leg) next rest
      | exception Leg_blocked -> Error (rejoin t ~before leg legs))

let rec walk_legs t ~rejoins at legs =
  match walk_on t ~before:None at legs with
  | Ok at -> at
  | Error _ when rejoins >= max_sign_rejoins ->
      fail "leg_blocked"
        "a message at every hold, after walking on before %d signs" rejoins
  | Error (at, legs) -> walk_legs t ~rejoins:(rejoins + 1) at legs

let walk t at legs =
  match
    Effects.with_probes Walk_interrupts.probes (fun () ->
        walk_legs t ~rejoins:0 at legs)
  with
  | at -> Ok at
  | exception Walk_failed cause -> Error cause
  | exception Grid_walker.Leg_walker.Interrupted_too_often s ->
      Error (Pokemon_checkpoints.Failure.cause "interrupted" s)
  | exception Walk_interrupts.Trainer_battle ->
      Error
        (Pokemon_checkpoints.Failure.cause "trainer_battle"
           "a battle started after a message on the overworld")
  | exception Walk_interrupts.Message_stuck ->
      Error
        (Pokemon_checkpoints.Failure.cause "message_stuck"
           "a message on the overworld did not close")
