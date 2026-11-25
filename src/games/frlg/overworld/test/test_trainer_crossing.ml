(* Trainer_sight and Trainer_crossing on Bond Bridge: which tiles of a walk
   over it its trainers may see, how far Aroma Lady Nikki, who wanders, sees,
   and a walk past Aroma Lady Violet with and without her battle. *)

open Grid_geometry
open Grid_maps
open Frlg_overworld_fixtures
open Frlg_world
module Route_target = Frlg_overworld.Route_target
module Trainer_sight = Frlg_overworld.Trainer_sight

let names = [ "ThreeIsland_BondBridge"; "ThreeIsland_BerryForest" ]
let w = mgba_world names

let goal map (x, y) facing : Pokemon_engine.Pose.grid =
  { map; tiles = [ { x; y } ]; facing }

let plan ~from:(map, x, y, facing) goal =
  Route_target.plan w ~from:(place w map x y) ~facing:(Some facing) goal

(* Each press of the planned walk onto a tile a trainer may see, with the
   tiles the trainers stand on. *)
let seen ~from goal () =
  match plan ~from goal with
  | Error e -> "error: " ^ e
  | Ok legs ->
      let on_leg (leg : Connected_maps.place Grid_planning.Leg.t) =
        let tiles = match leg.kind with Walk { tiles; _ } -> tiles | _ -> 0 in
        let rec go place i acc =
          if i > tiles then List.rev acc
          else
            match Frlg_overworld.Frlg_steps.press w place leg.direction with
            | None -> List.rev acc
            | Some s ->
                let by = Trainer_sight.seeing w ~beaten:[] s.next in
                let acc =
                  if by = [] then acc
                  else
                    Printf.sprintf "%s by %s"
                      (Tile_pos.to_string s.next.tile)
                      (String.concat " "
                         (List.map
                            (fun (t : Trainer_sight.trainer) ->
                              Tile_pos.to_string t.at)
                            by))
                    :: acc
                in
                go s.next (i + 1) acc
        in
        go leg.start 1 []
      in
      String.concat "; " (List.concat_map on_leg legs)

module S = Scripted_screen
module Route_walk = Frlg_overworld.Route_walk

(* Walks the planned legs on a screen that [react]s to the presses; a fought
   trainer's battle takes the screen back to the overworld. The outcome, the
   presses and the log. *)
let walk_with ?react ~from:(map, x, y, facing) goal () =
  let screen = S.create ?react () in
  let log = ref [] in
  let fought = ref 0 in
  let walker : Route_walk.t =
    {
      world = w;
      gait = Walking;
      flee = (fun () -> ());
      fight_trainer =
        (fun () ->
          incr fought;
          S.show screen ~at_ms:screen.S.clock_ms S.Overworld;
          Ok ());
      watch_trainers = true;
      log = (fun line -> log := line :: !log);
    }
  in
  let from = place w map x y in
  let outcome =
    match Route_target.plan w ~from ~facing:(Some facing) goal with
    | Error e -> "no plan: " ^ e
    | Ok legs -> (
        match
          S.run screen (fun () ->
              Route_walk.walk walker { place = from; facing = Some facing } legs)
        with
        | Ok at -> "at " ^ place_text w at.place
        | Error cause ->
            "failed " ^ Pokemon_engine.Failure.cause_to_string cause)
  in
  String.concat "\n"
    (Printf.sprintf "%s; fought %d; %s" outcome !fought (S.presses_text screen)
    :: List.rev !log)

(* A trainer's text 2 s after the [nth] hold's end. *)
let speaks_after ~nth screen (p : S.press) =
  if S.holds_dpad p && p.index = nth then
    S.show screen ~at_ms:(p.at_ms + p.hold_ms + 2000) S.Dialog

let above_violet = ("ThreeIsland_BondBridge", 66, 8, Direction.East)
let west_of_violet = goal "ThreeIsland_BondBridge" (60, 10) None
let case name input expectation = { Table_test.name; input; expectation }
let bridge_east = ("ThreeIsland_BondBridge", 88, 10, Direction.West)
let forest_mat = goal "ThreeIsland_BerryForest" (43, 41) None

let () =
  Table_test.run "trainer_crossing"
    [
      case "the tiles Bond Bridge's trainers may see on the walk over it"
        (seen ~from:bridge_east forest_mat)
        "(66, 10) by (68, 10); (49, 10) by (50, 11); (48, 10) by (50, 11); \
         (33, 10) by (27, 10); (32, 10) by (27, 10); (31, 10) by (27, 10); \
         (30, 10) by (27, 10); (29, 10) by (27, 10); (29, 11) by (27, 10); \
         (28, 14) by (27, 10); (27, 14) by (27, 10); (26, 14) by (27, 10)";
      case "Aroma Lady Nikki, wandering, sees 5 tiles every way"
        (fun () ->
          String.concat " "
            (List.map
               (fun (x, y) ->
                 string_of_int
                   (Trainer_sight.sight_onto w ~beaten:[]
                      (place w "ThreeIsland_BondBridge" x y)))
               [ (33, 10); (34, 10); (28, 12); (66, 10); (65, 10) ]))
        "5 0 5 2 0";
      case "Violet sees the player step onto (66, 10): her battle, then on"
        (walk_with ~react:(speaks_after ~nth:1) ~from:above_violet
           west_of_violet)
        "at ThreeIsland_BondBridge (60, 10); fought 1; down, down 533, left, \
         left 1468\n\
         Route: south 2\n\
         Route: a trainer saw the player on (66, 10): their battle.\n\
         Route: the trainer stands on (67, 10); on from (66, 10).\n\
         Route: west 6";
      case "nobody speaks on (66, 10): the walk goes on"
        (walk_with ~from:above_violet west_of_violet)
        "at ThreeIsland_BondBridge (60, 10); fought 0; down, down 533, left, \
         left 1468\n\
         Route: south 2\n\
         Route: no trainer spoke on (66, 10) in 3034ms.\n\
         Route: west 6";
    ]
