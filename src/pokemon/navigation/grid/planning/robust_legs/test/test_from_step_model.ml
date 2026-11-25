(* The leg planner's step model (Grid_planning.Step_model) as a robust one:
   'W' (a warp) and 'A' (a special step) are stops that aren't held, so the
   robust planner walks round them rather than crossing or holding against
   them. Ported from the C++ fork's Pokemon_RobustLegPlanner_Tests.cpp
   (RobustModelFromLegModel). *)

open Grid_geometry
open Grid_planning
open Grid_robust_legs
open Robust_toy

type Leg.special_step += Toy_special_step

let press rows p direction =
  let next = Tile_pos.next p direction in
  let step = Leg.plain_step next direction in
  match at rows next with
  | '#' -> None
  | 'W' -> Some { step with warped = true; ends_leg = true }
  | 'A' -> Some { step with special_step = Some Toy_special_step }
  | '"' -> Some { step with wild = true }
  | _ -> Some step

let rows = [ ".W.w."; "....."; "#..A." ]

let model =
  Robust_model.of_step_model
    ~wander:(fun p -> at rows p = 'w')
    ~wild:(fun p -> at rows p = '"')
    (Step_model.simple ~compare_state:Tile_pos.compare ~press:(press rows)
       ~held_at:(fun p direction -> at rows (Tile_pos.next p direction) = '#'))

let held p direction () = string_of_bool (model.held_at p direction)
let case name input expectation = { Table_test.name; input; expectation }

let cases =
  [
    case "a warp is a stop that isn't held" (held (pos 0 0) East) "false";
    case "a special step is a stop that isn't held"
      (held (pos 2 2) East)
      "false";
    case "a wall is held" (held (pos 0 0) North) "true";
    case "a plan walks round the warp and the wanderer"
      (fun () ->
        describe
          (Robust_planner.plan ~costs:exact model
             ~from:[ pos 0 0 ]
             ~at_goal:(Tile_pos.equal (pos 4 0))))
      "south 1 to wall: (0, 1); east 4 to wall: (4, 1); north 1 to wall: (4, 0)";
  ]

let () = Table_test.run "Robust_model.of_step_model" cases
