(* Sevii 05's walks: out of Three Island past where 04's Bikers stood
   (Scene_removed_people), west over Bond Bridge into the Berry Forest, and
   through the forest to Lostelle; which tiles of the walk its trainers may
   see (Trainer_sight). *)

open Grid_geometry
open Grid_maps
open Frlg_overworld_fixtures
open Frlg_world
module Route_target = Frlg_overworld.Route_target
module Trainer_sight = Frlg_overworld.Trainer_sight

let names =
  [ "ThreeIsland"; "ThreeIsland_BondBridge"; "ThreeIsland_BerryForest" ]

let w = mgba_world names

let goal map (x, y) facing : Pokemon_checkpoints.Pose.grid =
  { map; tiles = [ { x; y } ]; facing }

let plan ~from:(map, x, y, facing) goal =
  Route_target.plan w ~from:(place w map x y) ~facing:(Some facing) goal

let walk ~from goal () = legs_text w (plan ~from goal)

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
            "failed " ^ Pokemon_checkpoints.Failure.cause_to_string cause)
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
let from_center = ("ThreeIsland", 14, 28, Direction.South)
let forest_mat = goal "ThreeIsland_BerryForest" (43, 41) None

let () =
  Table_test.run "berry_forest"
    [
      case "from the Center over Bond Bridge into the forest"
        (walk ~from:from_center forest_mat)
        "west 5 -> ThreeIsland (9, 28) west; north 18 -> ThreeIsland (9, 10) \
         north; west 17 -> ThreeIsland_BondBridge (88, 10) west; north 4 (to \
         wall) -> ThreeIsland_BondBridge (88, 6) north; west 1 (to wall) -> \
         ThreeIsland_BondBridge (87, 6) west; south 2 (to wall) -> \
         ThreeIsland_BondBridge (87, 8) south; west 4 (to wall) -> \
         ThreeIsland_BondBridge (83, 8) west; south 6 (to wall) -> \
         ThreeIsland_BondBridge (83, 14) south; west 8 -> \
         ThreeIsland_BondBridge (75, 14) west; north 5 (to wall) -> \
         ThreeIsland_BondBridge (75, 9) north; east 2 -> \
         ThreeIsland_BondBridge (77, 9) east; north 2 -> \
         ThreeIsland_BondBridge (77, 7) north; west 1 -> \
         ThreeIsland_BondBridge (76, 7) west; north 2 (to wall) -> \
         ThreeIsland_BondBridge (76, 5) north; west 13 (to wall) -> \
         ThreeIsland_BondBridge (63, 5) west; south 3 (to wall) -> \
         ThreeIsland_BondBridge (63, 8) south; east 3 -> \
         ThreeIsland_BondBridge (66, 8) east; south 2 -> \
         ThreeIsland_BondBridge (66, 10) south; west 8 (to wall) -> \
         ThreeIsland_BondBridge (58, 10) west; north 4 (to wall) -> \
         ThreeIsland_BondBridge (58, 6) north; west 9 -> \
         ThreeIsland_BondBridge (49, 6) west; south 4 -> \
         ThreeIsland_BondBridge (49, 10) south; west 20 -> \
         ThreeIsland_BondBridge (29, 10) west; south 4 (to wall) -> \
         ThreeIsland_BondBridge (29, 14) south; west 13 -> \
         ThreeIsland_BondBridge (16, 14) west; north 5 (to wall) -> \
         ThreeIsland_BondBridge (16, 9) north; west 3 -> \
         ThreeIsland_BondBridge (13, 9) west; north 4 (warp) -> \
         ThreeIsland_BerryForest (43, 41) north";
      case "the tiles its trainers may see"
        (seen ~from:from_center forest_mat)
        "(66, 10) by (68, 10); (49, 10) by (50, 11); (48, 10) by (50, 11); \
         (33, 10) by (27, 10); (32, 10) by (27, 10); (31, 10) by (27, 10); \
         (30, 10) by (27, 10); (29, 10) by (27, 10); (29, 11) by (27, 10); \
         (28, 14) by (27, 10); (27, 14) by (27, 10); (26, 14) by (27, 10)";
      case "the forest's pacing along row 39, held to its walls"
        (fun () ->
          String.concat " | "
            (List.map
               (fun (from, x) ->
                 walk
                   ~from:("ThreeIsland_BerryForest", from, 39, Direction.West)
                   (goal "ThreeIsland_BerryForest" (x, 39) None)
                   ())
               [ (44, 30); (30, 44) ]))
        "west 14 (to wall) -> ThreeIsland_BerryForest (30, 39) west | east 14 \
         (to wall) -> ThreeIsland_BerryForest (44, 39) east";
      case "from the mat to the pacing's west wall"
        (walk
           ~from:("ThreeIsland_BerryForest", 43, 41, Direction.North)
           (goal "ThreeIsland_BerryForest" (30, 39) None))
        "north 2 -> ThreeIsland_BerryForest (43, 39) north; west 13 (to wall) \
         -> ThreeIsland_BerryForest (30, 39) west";
      case "through the forest to below Lostelle"
        (walk
           ~from:("ThreeIsland_BerryForest", 43, 41, Direction.North)
           (goal "ThreeIsland_BerryForest" (4, 9) (Some North)))
        "north 4 -> ThreeIsland_BerryForest (43, 37) north; west 13 (to wall) \
         -> ThreeIsland_BerryForest (30, 37) west; north 12 (to wall) -> \
         ThreeIsland_BerryForest (30, 25) north; east 5 (to wall) -> \
         ThreeIsland_BerryForest (35, 25) east; north 4 (to wall) -> \
         ThreeIsland_BerryForest (35, 21) north; east 2 (to wall) -> \
         ThreeIsland_BerryForest (37, 21) east; north 3 (to wall) -> \
         ThreeIsland_BerryForest (37, 18) north; east 1 (to wall) -> \
         ThreeIsland_BerryForest (38, 18) east; south 1 (to wall) -> \
         ThreeIsland_BerryForest (38, 19) south; east 3 (to wall) -> \
         ThreeIsland_BerryForest (41, 19) east; south 6 (to wall) -> \
         ThreeIsland_BerryForest (41, 25) south; east 2 (to wall) -> \
         ThreeIsland_BerryForest (43, 25) east; south 4 (to wall) -> \
         ThreeIsland_BerryForest (43, 29) south; west 2 -> \
         ThreeIsland_BerryForest (41, 29) west; south 4 -> \
         ThreeIsland_BerryForest (41, 33) south; east 6 (to wall) -> \
         ThreeIsland_BerryForest (47, 33) east; north 28 (to wall) -> \
         ThreeIsland_BerryForest (47, 5) north; west 25 -> \
         ThreeIsland_BerryForest (22, 5) west; south 7 (to wall) -> \
         ThreeIsland_BerryForest (22, 12) south; west 2 -> \
         ThreeIsland_BerryForest (20, 12) west; south 4 -> \
         ThreeIsland_BerryForest (20, 16) south; west 11 (to wall) -> \
         ThreeIsland_BerryForest (9, 16) west; south 7 -> \
         ThreeIsland_BerryForest (9, 23) south; east 13 -> \
         ThreeIsland_BerryForest (22, 23) east; south 6 (to wall) -> \
         ThreeIsland_BerryForest (22, 29) south; west 18 -> \
         ThreeIsland_BerryForest (4, 29) west; north 20 (to wall) -> \
         ThreeIsland_BerryForest (4, 9) north";
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
