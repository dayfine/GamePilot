(* Sevii 03's walks through Two Island's Joyful Game Corner: in by its door,
   and out from where the owner's scene leaves the player, to the harbor's
   sailor. The Biker on the door tile is shown only by the scene. *)

open Grid_geometry
open Frlg_overworld_fixtures
open Frlg_world
module Route_target = Frlg_overworld.Route_target

let names = [ "TwoIsland"; "TwoIsland_JoyfulGameCorner"; "TwoIsland_Harbor" ]

let walk ~from:(map, x, y, facing) (goal_map, tx, ty, goal_facing) () =
  let w = mgba_world names in
  let goal : Pokemon_engine.Pose.grid =
    {
      map = goal_map;
      tiles = [ { x = tx; y = ty } ];
      facing = Some goal_facing;
    }
  in
  legs_text w
    (Route_target.plan w ~from:(place w map x y) ~facing:(Some facing) goal)

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "joyful_game_corner"
    [
      case "in by the door, onto its mat"
        (walk
           ~from:("TwoIsland", 39, 10, Direction.East)
           ("TwoIsland_JoyfulGameCorner", 5, 8, North))
        "north 1 (warp) -> TwoIsland_JoyfulGameCorner (5, 8) north";
      (* Through the door tile, where the map has the Biker. *)
      case "out from the scene's end, to the harbor's sailor"
        (walk
           ~from:("TwoIsland_JoyfulGameCorner", 4, 8, Direction.East)
           ("TwoIsland_Harbor", 8, 5, South))
        "east 1 -> TwoIsland_JoyfulGameCorner (5, 8) east; south 1 (warp) -> \
         TwoIsland (39, 10) south; west 11 (to wall) -> TwoIsland (28, 10) \
         west; north 1 -> TwoIsland (28, 9) north; west 8 -> TwoIsland (20, 9) \
         west; south 4 (to wall) -> TwoIsland (20, 13) south; west 5 (to wall) \
         -> TwoIsland (15, 13) west; north 9 (to wall) -> TwoIsland (15, 4) \
         north; west 5 -> TwoIsland (10, 4) west; south 5 (warp) -> \
         TwoIsland_Harbor (8, 3) south; south 2 (to wall) -> TwoIsland_Harbor \
         (8, 5) south";
    ]
