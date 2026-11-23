(* The route log lines, word for word: BDSP-style position sets (several
   tiles, map names with spaces) and FRLG-style single tiles. Ported from
   Pokemon_RouteLog_Tests.cpp. *)

open Grid_maps
open Grid_trace

let tile map x y = { Route_tile.map; pos = { Tile_pos.x; y } }

(* A BDSP-style position: every tile the player may be on. *)
let bdsp_from = [ tile "Route 202" 15 25; tile "Route 202" 16 25 ]
let bdsp_wall = [ tile "Route 202" 23 25; tile "Route 202" 30 26 ]

(* An FRLG-style position: the one tile. *)
let frlg_tile = [ tile "Route1" 12 21 ]
let bdsp_grass = [ tile "Route 202" 23 17 ]
let frlg_north = [ tile "Route1" 12 13 ]
let trainer_seen = [ tile "Route 202" 20 10 ]
let arrived = [ tile "Route 202" 20 25 ]

let leg ?(action = Route_leg.Walk) ?(tiles = 0) ?(leg_end = Route_leg.Open)
    direction =
  { Route_leg.action; direction; tiles; leg_end }

let east_to_wall = leg ~tiles:15 ~leg_end:Wall East
let north_open = leg ~tiles:8 North
let south_warp = leg ~tiles:1 ~leg_end:Warp South

let bdsp_legs =
  [
    { Route_leg.leg = east_to_wall; after = bdsp_wall };
    { leg = north_open; after = bdsp_grass };
  ]

let frlg_legs = [ { Route_leg.leg = north_open; after = frlg_north } ]
let case name input expectation = { Case_table.name; input; expectation }

let leg_cases =
  [
    case "to a wall"
      (fun () -> Route_leg.to_string east_to_wall)
      "east 15 (to wall)";
    case "open" (fun () -> Route_leg.to_string north_open) "north 8 (open)";
    case "onto a warp"
      (fun () -> Route_leg.to_string south_warp)
      "south 1 (warp)";
    case "surf"
      (fun () -> Route_leg.to_string (leg ~action:Surf East))
      "surf east";
    case "face"
      (fun () -> Route_leg.to_string (leg ~action:Face West))
      "face west";
    case "open gate"
      (fun () -> Route_leg.to_string (leg ~action:Open_gate West))
      "open gate west";
    case "press switch"
      (fun () -> Route_leg.to_string (leg ~action:Press_switch North))
      "press switch north";
  ]

let plan_cases =
  [
    case "plan from a set of tiles"
      (fun () ->
        Route_log.plan_line ~label:"To the grass" ~from:bdsp_from bdsp_legs)
      "To the grass: plan from Route 202 (15, 25), Route 202 (16, 25): east 15 \
       (to wall) to Route 202 (23, 25), Route 202 (30, 26); north 8 (open) to \
       Route 202 (23, 17)";
    case "plan from one tile"
      (fun () ->
        Route_log.plan_line ~label:"00.05/2 below_mart_door" ~from:frlg_tile
          frlg_legs)
      "00.05/2 below_mart_door: plan from Route1 (12, 21): north 8 (open) to \
       Route1 (12, 13)";
    case "plan from an unknown tile"
      (fun () -> Route_log.plan_line ~label:"x" ~from:[] [])
      "x: plan from an unknown tile:";
    case "leg as it starts"
      (fun () -> Route_log.leg_line ~number:1 ~count:5 (List.hd bdsp_legs))
      "Leg 1/5: east 15 (to wall) to Route 202 (23, 25), Route 202 (30, 26)";
  ]

let end_cases =
  [
    case "walked"
      (fun () ->
        Route_log.leg_end_line ~label:"To the grass" east_to_wall ~at:bdsp_wall
          Walked)
      "To the grass: east 15 (to wall): ended at Route 202 (23, 25), Route 202 \
       (30, 26) (walked).";
    case "assumed"
      (fun () ->
        Route_log.leg_end_line ~label:"r" ~why:"after a wild battle" north_open
          ~at:frlg_tile Assumed)
      "r: north 8 (open): ended at Route1 (12, 21) (assumed: after a wild \
       battle).";
    case "unknown"
      (fun () ->
        Route_log.leg_end_line ~label:"r" ~why:"stopped by a wild battle"
          north_open ~at:[] Unknown)
      "r: north 8 (open): ended at an unknown tile (unknown: stopped by a wild \
       battle).";
    case "replan where seen"
      (fun () ->
        Route_log.replan_line ~label:"To the grass" east_to_wall
          ~what:"stopped early after about 3 tiles" ~at:bdsp_from)
      "To the grass: east 15 (to wall): stopped early after about 3 tiles, at \
       Route 202 (15, 25), Route 202 (16, 25); planning again.";
    case "found again"
      (fun () -> Route_log.found_line ~label:"r" ~at:frlg_tile ~holds:2)
      "r: found again at Route1 (12, 21), after 2 hold(s).";
    case "trainer"
      (fun () ->
        Route_log.trainer_line ~label:"To the grass" ~who:"Youngster Tristan"
          ~at:trainer_seen)
      "To the grass: Youngster Tristan stopped us about Route 202 (20, 10).";
    case "arrived"
      (fun () -> Route_log.arrived_line ~label:"To the grass" ~at:arrived)
      "To the grass: arrived at Route 202 (20, 25).";
  ]

let () = Case_table.run "RouteLog" (leg_cases @ plan_cases @ end_cases)
