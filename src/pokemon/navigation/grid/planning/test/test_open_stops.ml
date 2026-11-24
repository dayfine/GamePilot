(* How the leg planner weighs legs that end in the open: after grass, after a
   map connection, and by the model's own risks. Ported from the C++ fork's
   Pokemon_LegPlanner_Tests.cpp. *)

open Grid_maps
open Grid_planning
open Leg_case

let pos x y = { Tile_pos.x; y }

(* Outweighs any detour in these maps. *)
let heavy = 300
let wild_stop = { Leg_costs.default with per_open_wild_stop = heavy }

let connection_stop =
  { Leg_costs.default with per_open_connection_stop = heavy }

(* Two ways down to (3, 2): turn south right after the first three tiles,
   stopping in the open, or walk on to the wall and come back along the
   bottom row. The first is shorter by more than an open stop costs. *)
let detour first_row = [ first_row; "###.########."; "###.........." ]
let grass_detour = detour ".\"\".........."
let floor_detour = detour "............."

(* Weighs an open stop east after a leg of 3 or more tiles before a turn,
   and one of 2 tiles where the walk ends. *)
let check_risk _ (direction : Direction.t) ~run ~next =
  match (direction, next) with
  | East, Some _ when run = Step_model.max_counted_run -> heavy
  | East, None when run = 2 -> heavy
  | _ -> 0

let with_check_risk rows =
  { (Toy_game.model rows) with open_check_risk = Some check_risk }

let with_open_risk rows =
  { (Toy_game.model rows) with open_stop_risk = Some (fun _ _ -> heavy) }

let with_tap_risk rows =
  { (with_open_risk rows) with tap_stop_risk = Some (fun _ _ -> Some 0) }

let tap_map = [ ".#######"; "........"; "#.#####."; "#......." ]

(* The first leg stops in the open at x = 3 after the grass. *)
let open_at_3 = leg 0 (not_ to_wall &&& ends_at_x 3)

let weight_cases =
  [
    {
      name = "an open stop after grass, unweighed";
      input = walk grass_detour ~from:(pos 0 0) ~goal:(pos 3 2);
      expectation =
        {
          says = "a wild leg east stopping in the open at x = 3";
          holds = route (open_at_3 &&& leg 0 wild);
        };
    };
    {
      name = "an open stop after grass is weighed";
      input = walk grass_detour ~costs:wild_stop ~from:(pos 0 0) ~goal:(pos 3 2);
      expectation =
        {
          says = "the first leg east to the wall";
          holds = route (leg 0 to_wall);
        };
    };
    {
      name = "the weight needs a wild step";
      input = walk floor_detour ~costs:wild_stop ~from:(pos 0 0) ~goal:(pos 3 2);
      expectation =
        {
          says = "a leg stopping in the open at x = 3, not wild";
          holds = route (open_at_3 &&& leg 0 (not_ wild));
        };
    };
    {
      name = "a new leg is not wild";
      input =
        walk
          ([ ".\"\"###"; "##.###"; "##...#" ]
          @ List.init 9 (fun _ -> "##.#.#")
          @ [ "##...#" ])
          ~costs:wild_stop ~from:(pos 0 0) ~goal:(pos 4 2);
      expectation =
        {
          says =
            "3 legs: wild east to the wall, then south stopping in the open at \
             (2, 2)";
          holds =
            route
              (count 3
              &&& leg 0 (wild &&& to_wall)
              &&& leg 1 (not_ wild &&& not_ to_wall &&& ends_at (pos 2 2)));
        };
    };
  ]

let connection_map = detour ".CC.........."

let risk_cases =
  [
    {
      name = "an open stop after a connection, unweighed";
      input = walk connection_map ~from:(pos 0 0) ~goal:(pos 3 2);
      expectation = { says = "an open stop at x = 3"; holds = route open_at_3 };
    };
    {
      name = "an open stop after a connection is weighed";
      input =
        walk connection_map ~costs:connection_stop ~from:(pos 0 0)
          ~goal:(pos 3 2);
      expectation =
        {
          says = "the first leg east to the wall";
          holds = route (leg 0 to_wall);
        };
    };
    {
      name = "open_check_risk weighs the run before a turn";
      input =
        walk floor_detour ~model:with_check_risk ~from:(pos 0 0) ~goal:(pos 3 2);
      expectation =
        {
          says = "the first leg east to the wall";
          holds = route (leg 0 to_wall);
        };
    };
    {
      name = "open_check_risk weighs where the walk ends";
      input =
        walk [ "...."; "...." ] ~model:with_check_risk ~from:(pos 0 1)
          ~goal:(pos 2 1);
      expectation =
        {
          says = "the last leg south to the wall";
          holds = route (last (going South &&& to_wall));
        };
    };
    {
      name = "open_stop_risk alone";
      input = walk tap_map ~model:with_open_risk ~from:(pos 0 0) ~goal:(pos 1 3);
      expectation =
        {
          says = "a detour to the east wall as the second leg";
          holds = route (leg 1 to_wall);
        };
    };
    {
      name = "tap_stop_risk overrides open_stop_risk after a wall hold";
      input = walk tap_map ~model:with_tap_risk ~from:(pos 0 0) ~goal:(pos 1 3);
      expectation =
        {
          says = "3 legs, the second a 1-tile tap east off the wall";
          holds = route (count 3 &&& leg 1 (tiles 1 &&& not_ to_wall));
        };
    };
  ]

let () =
  List.iter run (weight_cases @ risk_cases);
  Table_test.finish ()
