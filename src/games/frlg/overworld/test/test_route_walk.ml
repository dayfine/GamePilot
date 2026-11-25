(* Walking planned routes against a scripted screen (Scripted_screen): the
   behaviour of the fork's PokemonFRLG_OverworldWalk_Tests (a warp's fade
   waited out, a wild battle fled and the leg to a wall walked again, a
   trainer's battle after a message stops the walk, a warp with no fade
   fails) on Pallet Town's maps, read through the FRLG readers from recorded
   mGBA frames. *)

open Frlg_overworld_fixtures
open Frlg_world
open Frlg_overworld
module S = Frlg_overworld_fixtures.Scripted_screen

let fled = ref 0

(* Fleeing takes the screen back to the overworld, for good: the rest of the
   battle the script set up (its screen after the flashes) is skipped. *)
let walker screen log : Route_walk.t =
  {
    world = pallet;
    gait = Walking;
    flee =
      (fun () ->
        incr fled;
        screen.S.shows <- [ (screen.S.clock_ms, S.Overworld) ]);
    fight_trainer = (fun () -> Ok ());
    watch_trainers = false;
    log = (fun line -> log := line :: !log);
  }

let target map tiles : Pokemon_checkpoints.Pose.grid =
  {
    map;
    tiles = List.map (fun (x, y) -> { Grid_geometry.Tile_pos.x; y }) tiles;
    facing = None;
  }

let at_text (at : Route_walk.at) =
  place_text pallet at.place
  ^ Option.fold ~none:""
      ~some:(fun d -> " " ^ Grid_geometry.Direction.name d)
      at.facing

(* Plans from [from] to [goal] and walks it on a screen that [react]s to the
   presses; the outcome, then the presses. *)
let walk ?react ?(logged = false) ~from goal () =
  let screen = S.create ?react () in
  let log = ref [] in
  fled := 0;
  let legs = Result.get_ok (Route_target.plan pallet ~from ~facing:None goal) in
  let outcome =
    S.run screen (fun () ->
        Route_walk.walk (walker screen log) { place = from; facing = None } legs)
  in
  let outcome =
    match outcome with
    | Ok at -> "at " ^ at_text at
    | Error cause ->
        "failed " ^ Pokemon_checkpoints.Failure.cause_to_string cause
  in
  let walked =
    Printf.sprintf "%s; fled %d; %s" outcome !fled (S.presses_text screen)
  in
  if logged then String.concat "\n" (walked :: List.rev !log) else walked

(* The black of a warp after the hold onto it, then the new map. *)
let fade_after_hold screen (p : S.press) =
  if S.holds_dpad p && p.hold_ms > 160 then (
    let ends = p.at_ms + p.hold_ms in
    S.show screen ~at_ms:(ends + 50) S.Black;
    S.show screen ~at_ms:(ends + 450) S.Overworld)

(* A screen [screen] shows [after_ms] into the first hold of [nth]. *)
let during_hold ~nth ~after_ms what screen (p : S.press) =
  if S.holds_dpad p && p.index = nth then
    S.show screen ~at_ms:(p.at_ms + after_ms) what

(* A sign speaks 100ms into each of the first [n] holds [d]: the walk was held
   into one the plan did not walk into. B closes it. *)
let sign_speaks ~n d screen (p : S.press) =
  let held (q : S.press) = List.mem d q.buttons && q.hold_ms > 160 in
  if held p && List.length (List.filter held screen.S.presses) <= n then
    S.show screen ~at_ms:(p.at_ms + 100) S.Dialog;
  if p.buttons = [ Wire.B ] then
    S.show screen ~at_ms:(p.at_ms + 100) S.Overworld

(* Run 4 of mg-04 (mGBA, 2026-11-23): a wild battle set off by the second
   tile of a three-tile hold flashes just after the hold's release, and its
   screen shows seconds later. *)
let flash_after_release screen (p : S.press) =
  if S.holds_dpad p && p.index = 1 then (
    S.show screen ~at_ms:(p.at_ms + 700) S.Flash;
    S.show screen ~at_ms:(p.at_ms + 760) S.Overworld;
    S.show screen ~at_ms:(p.at_ms + 2500) S.Battle)

let in_house = place pallet "PalletTown_PlayersHouse_1F" 4 6
let route1_top = place pallet "Route1" 12 5
let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "route_walk"
    [
      case "out of the house: the exit mat's fade is waited out"
        (walk ~react:fade_after_hold ~from:in_house
           (target "PalletTown" [ (6, 8) ]))
        "at PalletTown (6, 8) south; fled 0; down, down 667";
      case "no fade after the hold onto the warp fails the walk"
        (walk ~from:in_house (target "PalletTown" [ (6, 8) ]))
        "failed no_warp_fade: no fade after the hold onto the warp; fled 0; \
         down, down 667";
      case "a wild battle in the grass is fled, and the leg walked on"
        (walk
           ~react:(during_hold ~nth:1 ~after_ms:1000 S.Battle)
           ~from:(place pallet "Route1" 14 3)
           (target "Route1" [ (14, 12) ]))
        "at Route1 (14, 12) south; fled 1; down, down 2269 x2";
      case "a battle flashing just after the hold: the leg's last tile walked"
        (walk ~logged:true ~react:flash_after_release
           ~from:(place pallet "Route1" 14 3)
           (target "Route1" [ (14, 6) ]))
        "at Route1 (14, 6) south; fled 1; down, down 667, down\n\
         Route: south 3\n\
         Leg: a wild battle after 760ms, about 2 tiles walked, 1 to go.";
      case "a message, then a trainer's battle: the walk stops"
        (walk
           ~react:(fun screen p ->
             during_hold ~nth:1 ~after_ms:300 S.Dialog screen p;
             if p.buttons = [ Wire.B ] then (
               S.show screen ~at_ms:(p.at_ms + 100) S.Overworld;
               S.show screen ~at_ms:(p.at_ms + 2000) S.Battle))
           ~from:route1_top
           (target "Route1" [ (7, 24) ]))
        "failed trainer_battle: a battle started after a message on the \
         overworld; fled 0; up, up 400, B";
      case "a sign at every hold: the walk goes on from before it"
        (walk ~logged:true
           ~react:(sign_speaks ~n:2 Wire.Down)
           ~from:(place pallet "PalletTown" 12 9)
           (target "PalletTown" [ (10, 16) ]))
        "at PalletTown (10, 16) south; fled 0; left, left 400, down, down \
         2403, B, down 2403, B, right x2, down, down 2136\n\
         Route: west 2\n\
         Route: south 7 (to wall)\n\
         Leg: a message after 100ms, walking to the wall again.\n\
         Leg: a message after 100ms, stopping the leg.\n\
         Route: a sign ahead speaks at every hold; on from (9, 10).\n\
         Route: east 1\n\
         Route: south 6 (to wall)";
      case "a message at every hold with no sign ahead fails the walk"
        (walk ~logged:true
           ~react:(sign_speaks ~n:9 Wire.Down)
           ~from:(place pallet "PalletTown" 12 8)
           (target "PalletTown" [ (10, 15) ]))
        "failed leg_blocked: south: a message at every hold; no sign on the \
         maps is ahead: off the route; fled 0; down, down 667, B, down 667, B\n\
         Route: south 3\n\
         Leg: a message after 100ms, about 0 tiles walked, 3 to go.\n\
         Leg: a message after 100ms, about 0 of 3 tiles walked, stopping the \
         leg.";
    ]
