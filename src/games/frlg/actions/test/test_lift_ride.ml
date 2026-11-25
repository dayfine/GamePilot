(* The lift_floor action: the presses that pick a floor (the fork's
   PokemonFRLG_AutoStoryHideout_Tests cases), and a ride on a scripted screen
   read through the FRLG readers from recorded frames. *)

open Frlg_actions
open Frlg_overworld_fixtures
module S = Scripted_screen

let presses ~from ~to_ =
  match Lift_ride.ride_of_floors ~from ~to_ with
  | None -> "no ride"
  | Some ride ->
      let { Lift_ride.direction; count } = Lift_ride.menu_presses ride in
      Printf.sprintf "%d %s" count (Grid_maps.Direction.name direction)

let arrival ~from ~to_ () =
  match Lift_ride.ride_of_floors ~from ~to_ with
  | None -> "no ride"
  | Some ride ->
      let at = Lift_ride.arrival ride in
      Printf.sprintf "%s %s" at.at_map (Grid_maps.Tile_pos.to_string at.at_tile)

let outcome = function
  | Ok () -> "ok"
  | Error cause -> "failed " ^ Checkpoints.Failure.cause_to_string cause

(* Store 1F to 4F. The step through the lift door fades to black and back; the
   last step south, off the lift's arrival tile, dims into the floor picked,
   here the overworld frame darkened (Flash), which then holds still. Steps are
   the walk's taps: longer than a turn, shorter than a menu tap. *)
let step_hold_ms = Grid_maps.Move_mechanics.frlg.walk.tap.hold_ms
let steps_south_out = 3

let ride_screen ~dims =
  let south = ref 0 in
  fun screen (p : S.press) ->
    let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
    match p.buttons with
    | [ Wire.Up ] when p.index = 0 ->
        show 100 S.Black;
        show 600 S.Overworld
    | [ Wire.Down ] when p.hold_ms = step_hold_ms ->
        incr south;
        if dims && !south = steps_south_out then show 200 S.Flash
    | _ -> ()

let ride ~dims () =
  let screen = S.create ~react:(ride_screen ~dims) () in
  let ride = Option.get (Lift_ride.ride_of_floors ~from:"1F" ~to_:"4F") in
  let result =
    S.run screen (fun () ->
        Menu_input.run (fun () -> Lift_ride.ride ~log:ignore ride))
  in
  Printf.sprintf "%s; %s" (outcome result) (S.presses_text screen)

let case name input expectation = { Table_test.name; input; expectation }

let presses_case name ~from ~to_ expected =
  case name (fun () -> presses ~from ~to_) expected

let () =
  Table_test.run "lift_ride"
    [
      presses_case "B2F to B4F: one down" ~from:"B2F" ~to_:"B4F" "1 south";
      presses_case "B4F to B1F: two down past EXIT" ~from:"B4F" ~to_:"B1F"
        "2 south";
      presses_case "B4F to B2F: one up" ~from:"B4F" ~to_:"B2F" "1 north";
      presses_case "B1F to B4F: two down" ~from:"B1F" ~to_:"B4F" "2 south";
      presses_case "the lift's own floor: no press" ~from:"B4F" ~to_:"B4F"
        "0 south";
      presses_case "no B3F on the panel" ~from:"B2F" ~to_:"B3F" "no ride";
      presses_case "EXIT is no floor" ~from:"B2F" ~to_:"EXIT" "no ride";
      presses_case "store 1F to 5F: two down past EXIT" ~from:"1F" ~to_:"5F"
        "2 south";
      presses_case "store 5F to 1F: two up past EXIT" ~from:"5F" ~to_:"1F"
        "2 north";
      presses_case "store 1F to 3F: two up" ~from:"1F" ~to_:"3F" "2 north";
      presses_case "store 1F to 4F: a tie goes down" ~from:"1F" ~to_:"4F"
        "3 south";
      presses_case "no lift has both B2F and 5F" ~from:"B2F" ~to_:"5F" "no ride";
      case "store 4F: below its lift door"
        (arrival ~from:"1F" ~to_:"4F")
        "CeladonCity_DepartmentStore_4F (6, 2)";
      case "hideout B4F: below its lift door"
        (arrival ~from:"B1F" ~to_:"B4F")
        "RocketHideout_B4F (20, 24)";
      case "a ride: in, the panel, 1F to 4F, out" (ride ~dims:true)
        "ok; up x3, left x3, up, A, down x3, A, B x5, left x5, down x3, right \
         x3, down x2";
      case "a ride whose way out never changes the scene fails"
        (ride ~dims:false)
        "failed lift_scene_stuck: a still scene after the lift did not show; \
         up x3, left x3, up, A, down x3, A, B x5, left x5, down x3, right x3, \
         down x2";
    ]
