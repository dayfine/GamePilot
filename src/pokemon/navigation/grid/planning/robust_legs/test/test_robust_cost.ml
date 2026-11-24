(* What the robust planner charges for given legs. Ported case by case from
   the C++ fork's Pokemon_RobustLegPlanner_Tests.cpp (COST_CASES). Default
   costs: 8 a leg, 1 a tile, 4 more a grass tile, 50 more for a leg that
   stops in the open. *)

open Grid_robust_legs
open Robust_toy

let leg ?(held = false) ~to_wall direction tiles after =
  { Robust_leg.direction; tiles; to_wall; after; held }

let costed ?(costs = Robust_costs.default) rows legs () =
  string_of_int (Robust_planner.cost ~costs (model rows) ~from:[ pos 0 0 ] legs)

let case name input expectation =
  { Table_test.name; input; expectation = string_of_int expectation }

let d = Robust_costs.default

let cases =
  [
    case "a wall leg costs a leg and its tiles"
      (costed [ "...#" ] [ leg ~to_wall:true East 2 [ pos 2 0 ] ])
      (8 + 2);
    case "an open leg costs its stop and open tiles on top"
      (costed
         ~costs:{ d with exact_open_tiles = 12; per_open_tile = 2 }
         [ "...#" ]
         [ leg ~to_wall:false East 1 [ pos 1 0 ] ])
      (8 + 50 + 3);
    case "each grass tile entered costs extra"
      (costed [ ".\"\"#" ] [ leg ~to_wall:true East 2 [ pos 2 0 ] ])
      (8 + 2 + (2 * 4));
    case "a cost with open_error_per 0"
      (costed
         ~costs:{ d with open_error_per = 0 }
         [ "........" ]
         [ leg ~to_wall:false East 3 [ pos 3 0 ] ])
      (8 + 50 + 3);
    case "a held leg pays no per_open_tile"
      (costed
         ~costs:{ held with per_open_tile = 2 }
         [ "........" ]
         [ leg ~held:true ~to_wall:false East 3 [ pos 2 0; pos 3 0; pos 4 0 ] ])
      (8 + 50 + 3);
    case "held legs the same way are not joined"
      (costed ~costs:held [ "........" ]
         [
           leg ~held:true ~to_wall:false East 2 [ pos 1 0; pos 2 0; pos 3 0 ];
           leg ~held:true ~to_wall:false East 2
             [ pos 2 0; pos 3 0; pos 4 0; pos 5 0 ];
         ])
      (2 * (8 + 50 + 2));
    case "each grass tile of an open leg costs per_open_wild_tile more"
      (costed
         ~costs:{ d with exact_open_tiles = 12; per_open_wild_tile = 10 }
         [ ".\"\"...." ]
         [ leg ~to_wall:false East 3 [ pos 3 0 ] ])
      (8 + 50 + 3 + (2 * (4 + 10)));
    case "per_open_wild_tile leaves a wall leg's grass alone"
      (costed
         ~costs:{ d with per_open_wild_tile = 10 }
         [ ".\"\"#" ]
         [ leg ~to_wall:true East 2 [ pos 2 0 ] ])
      (8 + 2 + (2 * 4));
  ]

let () = Table_test.run "Robust_planner.cost" cases
