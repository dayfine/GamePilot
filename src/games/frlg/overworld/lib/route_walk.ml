open Grid_maps

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

exception Walk_failed of Story.Failure.cause

let fail code fmt =
  Printf.ksprintf
    (fun s -> raise (Walk_failed (Story.Failure.cause code s)))
    fmt

let faded m =
  (Frlg_readers.Screen_facts.of_measurements m).fade
  <> Screen_state.Fade.No_fade

let wait_out_warp fade =
  (if not (Grid_walker.Watch_along.fired fade) then
     match Effects.await ~timeout_ms:warp_fade_timeout_ms faded with
     | Holds _ -> ()
     | Timeout -> fail "no_warp_fade" "no fade after the hold onto the warp");
  match
    Effects.await ~timeout_ms:fade_up_timeout_ms (fun m -> not (faded m))
  with
  | Holds _ -> ()
  | Timeout -> fail "fade_stuck" "the warp's fade did not come back up"

let walker t ~running ~wild : Grid_walker.Leg_walker.t =
  {
    mover = Route_legs.mover ~running;
    interrupts = Walk_interrupts.for_leg ~flee:t.flee ~wild;
    log = t.log;
    tracer = None;
  }

let hold t (spec : Grid_walker.Leg_spec.t) ~running ~warps ~wild ~turn_first =
  if turn_first then
    ignore (Effects.submit (Route_legs.turn_tap spec.direction));
  let walker = walker t ~running ~wild in
  let fade = Grid_walker.Watch_along.create faded in
  let hold_watchers = if warps then [ fade ] else [] in
  let result = Grid_walker.Leg_walker.walk_leg ~hold_watchers walker spec in
  if result.stopped then
    fail "leg_stopped" "%s stopped after about %d tiles"
      (Grid_walker.Leg_spec.to_string spec)
      result.tiles;
  if warps then wait_out_warp fade;
  let watch_ms = if wild then after_wild_leg_watch_ms else after_leg_watch_ms in
  ignore (Grid_walker.Leg_walker.clear_late_interrupts walker ~watch_ms : int)

let walk_one t at (leg : Connected_maps.place Grid_planning.Leg.t) =
  (match Route_legs.move_of t.world t.gait ~facing:at.facing leg with
  | Error e -> fail "route_unsupported" "%s" e
  | Ok (Turn d) ->
      if at.facing <> Some d then
        ignore (Effects.submit (Route_legs.turn_tap d))
  | Ok (Hold { spec; running; warps; wild; turn_first }) ->
      t.log ("Route: " ^ Grid_walker.Leg_spec.to_string spec);
      hold t spec ~running ~warps ~wild ~turn_first);
  { place = leg.finish; facing = Some leg.facing_after }

let walk t at legs =
  match List.fold_left (walk_one t) at legs with
  | at -> Ok at
  | exception Walk_failed cause -> Error cause
  | exception Grid_walker.Leg_walker.Interrupted_too_often s ->
      Error (Story.Failure.cause "interrupted" s)
  | exception Walk_interrupts.Trainer_battle ->
      Error
        (Story.Failure.cause "trainer_battle"
           "a battle started after a message on the overworld")
  | exception Walk_interrupts.Message_stuck ->
      Error
        (Story.Failure.cause "message_stuck"
           "a message on the overworld did not close")
