(* A leg planner case on the toy game: a map, a walk, and what the plan must
   be. Each case of the C++ tests that planned twice is two cases here. *)

open Grid_geometry
open Grid_planning

type input = {
  rows : string list;
  from : Tile_pos.t;
  goal : Tile_pos.t;
  goal_facing : Direction.t option;
  costs : Leg_costs.t;
  model : string list -> Tile_pos.t Step_model.t;
}

type expectation = {
  says : string;
  holds : Tile_pos.t Leg.t list option -> bool;
}

type t = { name : string; input : input; expectation : expectation }

let walk ?goal_facing ?(costs = Leg_costs.default) ?(model = Toy_game.model)
    rows ~from ~goal =
  { rows; from; goal; goal_facing; costs; model }

let plan input =
  Leg_planner.plan ~costs:input.costs (input.model input.rows) ~start:input.from
    ~start_facing:None
    ~at_goal:(Tile_pos.equal input.goal)
    ~goal_facing:input.goal_facing

let run { name; input; expectation } =
  let legs = plan input in
  Table_test.report name
    (Check.expect ~expected:expectation.says ~plan:(Toy_game.describe legs)
       (expectation.holds legs))

(* Predicates on a plan. *)

let route holds = function Some legs -> holds legs | None -> false
let no_route = Option.is_none
let count n legs = List.length legs = n
let nth i legs = if i < 0 then None else List.nth_opt legs i

let leg i holds legs =
  match nth i legs with Some leg -> holds leg | None -> false

let last holds legs = leg (List.length legs - 1) holds legs

let to_wall (leg : _ Leg.t) =
  match leg.kind with
  | Walk { to_wall; _ } -> to_wall
  | Action _ | Face -> false

let tiles n (leg : _ Leg.t) =
  match leg.kind with
  | Walk { tiles; _ } -> tiles = n
  | Action _ | Face -> false

let going direction (leg : _ Leg.t) = leg.direction = direction
let wild (leg : _ Leg.t) = leg.wild
let ends_at pos (leg : _ Leg.t) = Tile_pos.equal leg.finish pos
let ends_at_x x (leg : Tile_pos.t Leg.t) = leg.finish.x = x
let ( &&& ) p q leg = p leg && q leg
let not_ p leg = not (p leg)
