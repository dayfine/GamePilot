(* The route scorer on small made-up grids. Ported case by case from the C++
   fork's Pokemon_RouteScorer_Tests.cpp, each check's numbers and verdicts
   written out as text. *)

open Grid_route_scoring
open Toy_score_map

let case name input expectation = { Table_test.name; input; expectation }

let taps_time () =
  let got =
    score [ "......" ] ~from:(pos 0 0) ~goal:(pos 4 0) [ leg Taps East 4 ]
  in
  Printf.sprintf "%s %d ms, %d presses, %d stops" (verdict got) got.nominal_ms
    got.presses got.stops

let run_to_wall_beats_taps () =
  let rows = [ "......#" ] in
  let taps = score rows ~from:(pos 0 0) ~goal:(pos 5 0) [ leg Taps East 5 ] in
  let run =
    score rows ~from:(pos 0 0) ~goal:(pos 5 0) [ leg ~run:true To_wall East 5 ]
  in
  Printf.sprintf "%s %d ms, %d stops, faster than taps: %b" (verdict run)
    run.nominal_ms run.stops
    (run.expected_ms < taps.expected_ms)

(* Three columns, all stopped by row 2's wall, then west to the wall. *)
let wall_collapses_a_set () =
  verdict
    (score
       [ "....."; "....."; "#####" ]
       ~from:(pos 2 0) ~goal:(pos 0 1)
       [
         leg ~run:true Open_hold East 2; leg To_wall South 1; leg To_wall West 4;
       ])

let both a b () = verdict (a ()) ^ "; " ^ verdict (b ())

let open_hold_before_a_wall =
  let rows = [ ".....#" ] in
  both
    (fun () ->
      score rows ~from:(pos 0 0) ~goal:(pos 4 0)
        [ leg ~run:true Open_hold East 4 ])
    (fun () ->
      score rows ~from:(pos 0 0) ~goal:(pos 4 0)
        [ leg ~run:true Open_hold East 3; leg ~run:true To_wall East 2 ])

let wall_leg_through_a_warp =
  let rows = [ "..D..#" ] in
  both
    (fun () ->
      score rows ~from:(pos 0 0) ~goal:(pos 4 0) [ leg To_wall East 4 ])
    (fun () ->
      score rows ~from:(pos 0 0) ~goal:(pos 2 0) [ leg To_wall East 2 ])

let grass_charges_interruptions () =
  let got =
    score [ ".\"\"\"..#" ] ~from:(pos 0 0) ~goal:(pos 5 0)
      [ leg To_wall East 5 ]
  in
  Printf.sprintf
    "%s, %d recoveries, %d replans, expected above nominal: %b, worst above \
     nominal: %b"
    (verdict got) got.recoveries got.replans
    (got.expected_ms > float_of_int got.nominal_ms)
    (got.worst_ms > got.nominal_ms)

(* A lost tap in the grass leaves the player a tile either way; the taps
   after it cannot tell, so without a replanner the plan fails. A replanner
   that goes east to the wall absorbs it. *)
let taps_in_grass_need_a_replan () =
  let taps = [ leg Taps East 5 ] in
  let failed = score [ ".\"\"\"...." ] ~from:(pos 0 0) ~goal:(pos 5 0) taps in
  let replanned =
    score
      ~replan:(always [ leg To_wall East 5 ])
      [ ".\"\"\"..#" ] ~from:(pos 0 0) ~goal:(pos 5 0) taps
  in
  Printf.sprintf "%s; %s with %d replans" (verdict failed) (verdict replanned)
    replanned.replans

(* Back west to the wall, then taps east through the grass again. *)
let back_through_the_grass = [ leg To_wall West 4; leg Taps East 5 ]

let recovered rows () =
  verdict
    (score
       ~replan:(always back_through_the_grass)
       rows ~from:(pos 1 0) ~goal:(pos 6 0)
       [ leg Taps East 5 ])

let too_many_recoveries () =
  verdict
    (score
       ~replan:(always [ leg To_wall East 5 ])
       ~model:{ model with max_recoveries = 0 }
       [ ".\"\"\"..#" ] ~from:(pos 0 0) ~goal:(pos 5 0)
       [ leg Taps East 5 ])

let trainer_sight_once () =
  let got =
    score [ ".ss...#" ] ~from:(pos 0 0) ~goal:(pos 5 0) [ leg To_wall East 5 ]
  in
  Printf.sprintf "%d recoveries, a trainer battle charged: %b" got.recoveries
    (got.expected_ms >= float_of_int (got.nominal_ms + model.trainer_ms))

let tiles_walked_back () =
  let bounce = [ leg To_wall East 5; leg Taps West 2 ] in
  let backtrack = [ leg Taps East 5; leg Taps South 1; leg Taps West 3 ] in
  Printf.sprintf "bounce %d, backtrack %d"
    (Scored_leg.tiles_walked_back bounce)
    (Scored_leg.tiles_walked_back backtrack)

let one_verdict rows ~goal legs () =
  verdict (score rows ~from:(pos 0 0) ~goal legs)

let cases =
  [
    case "taps take a tap each" taps_time "PASS 3300 ms, 4 presses, 0 stops";
    case "a run to a wall beats taps" run_to_wall_beats_taps
      "PASS 1850 ms, 1 stops, faster than taps: true";
    case "walls bring a set of tiles to one" wall_collapses_a_set "PASS";
    case "an open hold with nothing to stop it fails"
      (one_verdict [ "........" ] ~goal:(pos 3 0) [ leg Open_hold East 3 ])
      "FAIL";
    case "an open hold may not overshoot into grass"
      (one_verdict [ "....\"\"\"#" ] ~goal:(pos 6 0)
         [ leg Open_hold East 3; leg To_wall East 3 ])
      "FAIL";
    case "an open hold may not overshoot onto a ledge"
      (one_verdict
         [ "."; "."; "."; "v"; "."; "#" ]
         ~goal:(pos 0 4)
         [ leg Open_hold South 2; leg To_wall South 2 ])
      "FAIL";
    case "an open hold may overshoot toward a wall" open_hold_before_a_wall
      "FAIL; PASS";
    case "a hold may not walk into a warp" wall_leg_through_a_warp "FAIL; PASS";
    case "the goal's trigger stops a run"
      (one_verdict [ "..T...." ] ~goal:(pos 2 0)
         [ leg ~run:true To_wall East 2 ])
      "PASS";
    case "grass charges interruptions" grass_charges_interruptions
      "PASS, 3 recoveries, 0 replans, expected above nominal: true, worst \
       above nominal: true";
    case "taps in grass need a replan" taps_in_grass_need_a_replan
      "FAIL; PASS with 3 replans";
    (* The recovery walks back to the west wall, still in the grass, and taps
       east through it: an interruption there leads to the same recovery
       again, from tiles never known. *)
    case "a recovery back through the grass strands"
      (recovered [ "#\"\"\"\"...." ])
      "STRAND";
    (* The same, but the west wall stops the player on a tile out of the
       grass: the recovery starts from a known tile each time, so an
       interruption on the way back is a retry that ends, not a strand. *)
    case "a recovery from a wall out of the grass retries"
      (recovered [ "#.\"\"\"...." ])
      "PASS";
    case "recoveries in a row are capped" too_many_recoveries "RETRIES";
    case "a trainer sees us once" trainer_sight_once
      "1 recoveries, a trainer battle charged: true";
    case "tiles walked back ignores wall bounce taps" tiles_walked_back
      "bounce 0, backtrack 3";
    (* Not in the C++ tests: there, a hold stopped short of its shortest end
       had no end at all, so the plan passed from no tile. *)
    case "an open hold stopped short of its shortest end ends at the wall"
      (fun () ->
        let got =
          score [ "...#...." ] ~from:(pos 0 0) ~goal:(pos 6 0)
            [ leg Open_hold East 5 ]
        in
        verdict got ^ ": " ^ got.why)
      "FAIL: may end on (2, 0), off the goal";
  ]

let () = Table_test.run "Route_scorer" cases
