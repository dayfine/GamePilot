(* Sevii 05's walks: out of Three Island past where 04's Bikers stood
   (Scene_removed_people), west over Bond Bridge into the Berry Forest, and
   through the forest to Lostelle. Bond Bridge's trainers on the walk are in
   test_trainer_crossing. *)

open Grid_geometry
open Frlg_overworld_fixtures
open Frlg_world
module Route_target = Frlg_overworld.Route_target

let names =
  [ "ThreeIsland"; "ThreeIsland_BondBridge"; "ThreeIsland_BerryForest" ]

let w = mgba_world names

let goal map (x, y) facing : Pokemon_engine.Pose.grid =
  { map; tiles = [ { x; y } ]; facing }

let plan ~from:(map, x, y, facing) goal =
  Route_target.plan w ~from:(place w map x y) ~facing:(Some facing) goal

let walk ~from goal () = legs_text w (plan ~from goal)
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
    ]
