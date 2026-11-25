(* The robust planner on the toy game. Ported case by case from the C++
   fork's Pokemon_RobustLegPlanner_Tests.cpp (PLAN_CASES). Open legs on
   default costs may end a tile either way (two from 5 tiles up). *)

open Grid_geometry
open Grid_robust_legs
open Robust_toy

(* The plan from [from] to [goal], described. *)
let planned ?wraps ?costs rows ~from ~goal () =
  describe
    (Robust_planner.plan ?costs (model ?wraps rows) ~from
       ~at_goal:(Tile_pos.equal goal))

let case name input expectation = { Table_test.name; input; expectation }
let d = Robust_costs.default
let gather_rows = [ "....."; "#...#" ]
let lined_up = [ ".##"; "..."; "..."; ".##"; ".##" ]

let cases =
  [
    case "a wall gathers the possible tiles"
      (planned [ "...#" ] ~from:[ pos 0 0; pos 1 0 ] ~goal:(pos 2 0))
      "east 2 to wall: (2, 0)";
    case "no plan ends in the open while open legs may be off"
      (planned [ "........" ] ~from:[ pos 0 0 ] ~goal:(pos 3 0))
      "none";
    case "an exact open leg ends in the open"
      (planned ~costs:exact [ "........" ] ~from:[ pos 0 0 ] ~goal:(pos 3 0))
      "east 3 open: (3, 0)";
    case "open_error_per 0 with no open_error is exact"
      (planned
         ~costs:{ d with open_error = 0; open_error_per = 0 }
         [ "........" ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 0))
      "east 3 open: (3, 0)";
    case "open_error_per 0 keeps open_error"
      (planned
         ~costs:{ d with open_error = 1; open_error_per = 0 }
         [ "........" ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 0))
      "none";
    case "a door is not a wall"
      (planned ~costs:exact [ "#..D" ] ~from:[ pos 1 0 ] ~goal:(pos 2 0))
      "east 1 open: (2, 0)";
    case "no leg along a wander zone"
      (planned ~costs:exact [ ".www."; "....." ]
         ~from:[ pos 1 0 ]
         ~goal:(pos 4 0))
      "south 1 to wall: (1, 1); east 3 to wall: (4, 1); north 1 to wall: (4, 0)";
    case "a ledge hop counts 2 tiles"
      (planned [ "."; "v"; "." ] ~from:[ pos 0 0 ] ~goal:(pos 0 2))
      "south 2 to wall: (0, 2)";
    case "a tapped open leg over a ledge counts taps, not tile distance"
      (planned ~costs:exact
         [ "."; "."; "v"; "."; "."; "." ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 0 4))
      "south 3 open: (0, 4)";
    case "a ledge cannot be climbed"
      (planned [ "."; "v"; "." ] ~from:[ pos 0 2 ] ~goal:(pos 0 0))
      "none";
    case "tall grass costs less than a detour"
      (planned [ ".\"\".."; "....." ] ~from:[ pos 0 0 ] ~goal:(pos 4 0))
      "east 4 to wall: (4, 0)";
    case "costly tall grass is walked round"
      (planned
         ~costs:{ d with per_wild_tile = 20 }
         [ ".\"\".."; "....." ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 4 0))
      "south 1 to wall: (0, 1); east 4 to wall: (4, 1); north 1 to wall: (4, 0)";
    (* Only an open leg reaches the second row; a wall then gathers. *)
    case "an open leg spreads, a wall gathers"
      (planned gather_rows ~from:[ pos 0 0 ] ~goal:(pos 3 1))
      "east 1 open: (1, 0) (2, 0); south 1 to wall: (1, 1) (2, 1); east 2 to \
       wall: (3, 1)";
    case "a spread wider than max_spread is not planned"
      (planned ~costs:{ d with max_spread = 1 } gather_rows
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 1))
      "none";
    case "the search gives up past max_searched"
      (planned
         ~costs:{ d with max_searched = 1 }
         gather_rows
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 1))
      "none";
    case "two open legs the same way are one"
      (planned
         ~costs:{ d with exact_open_tiles = 12; max_open_tiles = 2 }
         [ "........" ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 0))
      "east 3 open: (3, 0)";
    case "a walk that is never stopped is not a wall"
      (planned ~wraps:true ~costs:exact [ "...." ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 2 0))
      "east 2 open: (2, 0)";
    case "an open leg that may end off is held"
      (planned ~costs:held gather_rows ~from:[ pos 0 0 ] ~goal:(pos 3 1))
      "east 1 held: (1, 0) (2, 0); south 1 to wall: (1, 1) (2, 1); east 2 to \
       wall: (3, 1)";
    case "a held leg is refused when its long end lands in tall grass"
      (planned ~costs:held [ "..\".."; "#...#" ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 1))
      "none";
    case "a held leg is refused when its long end lands where someone wanders"
      (planned ~costs:held [ "..w.."; "#...#" ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 1))
      "none";
    case "a held leg south lines up a wall leg"
      (planned ~costs:held lined_up ~from:[ pos 0 0 ] ~goal:(pos 2 2))
      "south 1 held: (0, 1) (0, 2); east 2 to wall: (2, 1) (2, 2); south 1 to \
       wall: (2, 2)";
    case "a held leg is refused when its long end hops a ledge"
      (planned ~costs:held
         [ ".##"; "..."; "v.."; ".##"; ".##" ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 2 2))
      "none";
    case "open legs are tapped while hold_open_legs is off"
      (planned
         ~costs:{ d with open_error = 1; open_error_per = 0 }
         gather_rows
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 1))
      "east 1 open: (1, 0) (2, 0); south 1 to wall: (1, 1) (2, 1); east 2 to \
       wall: (3, 1)";
    case "along_wander is forbidden by default"
      (planned [ ".ww."; "...." ] ~from:[ pos 0 0 ] ~goal:(pos 3 0))
      "south 1 to wall: (0, 1); east 3 to wall: (3, 1); north 1 to wall: (3, 0)";
    case "forbid_along_wander false allows walking along wander"
      (planned
         ~costs:{ d with forbid_along_wander = false }
         [ ".ww."; "...." ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 0))
      "east 3 to wall: (3, 0)";
    case "forbid_along_wander false avoids costly wander"
      (planned
         ~costs:{ d with per_wander_tile = 20; forbid_along_wander = false }
         [ ".ww."; "...." ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 0))
      "south 1 to wall: (0, 1); east 3 to wall: (3, 1); north 1 to wall: (3, 0)";
    (* South 1 (open) followed by east 5 (to wall) then west 2 (open) is an
       orthogonal turn into a walled row and back off the wall, not a
       redundant overshoot along the tapped axis. *)
    case "wall bounce after perpendicular tapped leg is allowed"
      (planned
         ~costs:{ d with exact_open_tiles = 2 }
         [ "......."; "......#"; "......." ]
         ~from:[ pos 0 0 ]
         ~goal:(pos 3 1))
      "south 1 open: (0, 1); east 5 to wall: (5, 1); west 2 open: (3, 1)";
  ]

let () = Table_test.run "Robust_planner.plan" cases
