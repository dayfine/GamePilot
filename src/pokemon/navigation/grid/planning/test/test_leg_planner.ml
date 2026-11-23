(* The leg planner on the toy game: walls, people, tall grass, a one-way tile
   and a warp. Ported from the C++ fork's Pokemon_LegPlanner_Tests.cpp; the
   cases that weigh open stops are in test_open_stops.ml. *)

open Grid_maps
open Grid_planning
open Leg_case

let pos x y = { Tile_pos.x; y }
let one_way = [ "#.#.#"; "#v#.#"; "#...#"; "#####" ]

let cases =
  [
    {
      name = "prefers legs that end at a wall";
      input =
        walk [ "......"; "...#.."; "......" ] ~from:(pos 0 0) ~goal:(pos 2 1);
      expectation =
        {
          says = "2 legs, the last east into the pillar";
          holds = route (count 2 &&& leg 1 (going East &&& to_wall));
        };
    };
    {
      name = "a person is not a wall";
      input = walk [ "#####"; "#..p#"; "#####" ] ~from:(pos 1 1) ~goal:(pos 2 1);
      expectation =
        {
          says = "one open leg";
          holds = route (count 1 &&& leg 0 (not_ to_wall));
        };
    };
    {
      name = "avoids tall grass";
      input =
        walk [ "....."; ".\"\"\"."; "....." ] ~from:(pos 0 1) ~goal:(pos 4 1);
      expectation =
        {
          says = "no leg ending in the grass (around is cheaper)";
          holds =
            route
              (List.for_all (fun (l : Tile_pos.t Leg.t) ->
                   not (l.finish.y = 1 && l.finish.x > 0 && l.finish.x < 4)));
        };
    };
    {
      name = "one-way tile, entered its way";
      input = walk one_way ~from:(pos 1 0) ~goal:(pos 1 2);
      expectation = { says = "a route down"; holds = route (fun _ -> true) };
    };
    {
      name = "one-way tile, not entered against it";
      input = walk one_way ~from:(pos 1 2) ~goal:(pos 1 0);
      expectation = { says = "no route back up"; holds = no_route };
    };
    {
      name = "a warp ends the leg";
      input =
        walk
          [ "#######"; "#W.#X.#"; "#..#..#"; "#######" ]
          ~from:(pos 2 2) ~goal:(pos 5 2);
      expectation =
        {
          says = "a warp leg, ending on X at (4, 1)";
          holds =
            route (fun legs ->
                let warps = List.filter (fun (l : _ Leg.t) -> l.warps) legs in
                warps <> [] && List.for_all (ends_at (pos 4 1)) warps);
        };
    };
    {
      name = "turns to face the goal";
      input = walk [ "...." ] ~goal_facing:North ~from:(pos 0 0) ~goal:(pos 2 0);
      expectation =
        {
          says = "a last leg turning north";
          holds =
            route
              (last (fun (l : Tile_pos.t Leg.t) ->
                   l.kind = Leg.Face && l.direction = Direction.North));
        };
    };
    {
      name = "nothing through a wall";
      input = walk [ ".#." ] ~from:(pos 0 0) ~goal:(pos 2 0);
      expectation = { says = "no route"; holds = no_route };
    };
    {
      name = "a leg through grass is wild";
      input = walk [ ".\"\"." ] ~from:(pos 0 0) ~goal:(pos 3 0);
      expectation =
        { says = "one wild leg"; holds = route (count 1 &&& leg 0 wild) };
    };
    {
      name = "a leg on floor is not wild";
      input = walk [ "...." ] ~from:(pos 0 0) ~goal:(pos 3 0);
      expectation =
        {
          says = "one leg, not wild";
          holds = route (count 1 &&& leg 0 (not_ wild));
        };
    };
  ]

let () =
  List.iter run cases;
  Case_table.finish ()
