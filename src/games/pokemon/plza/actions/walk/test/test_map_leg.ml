(* Map legs and Wild Zone 1's way out, as the C++'s tests check them
   (PokemonLZA_AutoStoryActions_Tests.cpp). *)

open Plza_walk
open Map_leg

let case name input expectation = { Table_test.name; input; expectation }
let p x y = { x; y }
let spot = { name = "the 100 spot"; pin = p 432. 238.; stop_radius = 12. }

let second_spot =
  { name = "the second catch spot"; pin = p 386. 252.; stop_radius = 12. }

(* Each read's move, and a walk's hold must be positive. *)
let moves (waypoint : waypoint) reads () =
  let _, texts =
    List.fold_left
      (fun (leg, texts) read ->
        let leg, move = next leg read in
        let text =
          match move with
          | Walk { hold_ms; _ } when hold_ms <= 0 -> "a hold of 0"
          | m -> move_text m
        in
        (leg, text :: texts))
      (start waypoint.pin ~stop_radius:waypoint.stop_radius, [])
      reads
  in
  String.concat ", " (List.rev texts)

let leg_cases =
  [
    case "a walk that ends short gets a correction, then arrives"
      (moves spot
         [ Some (p 456. 231.); Some (p 445. 234.); Some (p 431. 238.) ])
      "walk 254 deg, correction 1: walk 253 deg, arrived";
    case "still off after the leg and two corrections: stops"
      (moves spot
         [
           Some (p 456. 231.);
           Some (p 420. 220.);
           Some (p 445. 250.);
           Some (p 420. 225.);
         ])
      "walk 254 deg, correction 1: walk 146 deg, correction 2: walk 313 deg, \
       off target";
    case "a missing read gets a second look"
      (moves spot [ None; Some (p 433. 238.) ])
      "read again, arrived";
    case "two missing reads in a row stop"
      (moves spot [ None; None ])
      "read again, pin not read";
    case "a missing read after a walk is not a correction"
      (moves spot [ Some (p 456. 231.); None; Some (p 445. 234.) ])
      "walk 254 deg, read again, correction 1: walk 253 deg";
    case "a walk past a catch spot on its way, within its stop area, arrives"
      (moves second_spot [ Some (p 431. 236.); Some (p 380. 247.) ])
      "walk 250 deg, arrived";
    case
      "a walk that ends off to the side of a catch spot, out of its stop area, \
       gets a correction"
      (moves second_spot [ Some (p 431. 236.); Some (p 384. 265.) ])
      "walk 250 deg, correction 1: walk 9 deg";
    case "a first read within a catch spot's stop area arrives without a walk"
      (moves second_spot [ Some (p 380. 247.) ])
      "arrived";
  ]

let point_text q = Printf.sprintf "(%.0f, %.0f)" q.x q.y

(* The legs, and the run at the gate's heading (270 within 10). *)
let exit start () =
  let legs = Wild_zone_one.exit_legs start in
  let rec last_two = function
    | [ a; b ] -> (a, b)
    | [ b ] -> (start, b)
    | _ :: rest -> last_two rest
    | [] -> (start, start)
  in
  let from, gate = last_two legs in
  let heading = bearing from gate in
  Printf.sprintf "%s; the run at the gate heads %s"
    (String.concat ", " (List.map point_text legs))
    (if Float.abs (heading -. 270.) <= 10. then "along its line"
     else Printf.sprintf "%.0f" heading)

let exit_cases =
  [
    case "on the gate's line: one straight run"
      (exit (p 379. 250.))
      "(361, 252); the run at the gate heads along its line";
    case "north-east of the gate: diagonal straight to the gate run-up"
      (exit (p 399. 231.))
      "(375, 252), (361, 252); the run at the gate heads along its line";
    case "west of the gate: onto the line east of the gate"
      (exit (p 340. 240.))
      "(375, 252), (361, 252); the run at the gate heads along its line";
  ]

(* The check's outcome and how many pins it read. *)
let out_of_zone pins () =
  let reads = ref 0 in
  let pin () =
    let i = !reads in
    incr reads;
    match pins with
    | [] -> None
    | _ -> Some (List.nth pins (min i (List.length pins - 1)))
  in
  let outcome =
    match Wild_zone_one.check_out pin with
    | Ok reads -> "out: " ^ reads
    | Error c -> Engine_run.Failure.cause_to_string c
  in
  let reads = if pins = [] then 0 else !reads in
  Printf.sprintf "%s; %d reads" outcome reads

let out_cases =
  [
    case "out at the map's centre: one map read"
      (out_of_zone [ p 401. 225. ])
      "out: (401, 225); 1 reads";
    case "in the zone: no save there"
      (out_of_zone [ p 386. 252. ])
      "in_wild_zone: still in Wild Zone 1: the map pin reads (386, 252); 1 \
       reads";
    case "out off the map's centre, in on the next read: in the zone"
      (out_of_zone [ p 420. 262.; p 386. 252. ])
      "in_wild_zone: still in Wild Zone 1: the map pin reads (420, 262), (386, \
       252); 2 reads";
    case "no map pin: not known to be out" (out_of_zone [])
      "zone_unread: out of Wild Zone 1 not known: no map pin on read 1 of 2; 0 \
       reads";
    case "out off the map's centre twice: out"
      (out_of_zone [ p 420. 262. ])
      "out: (420, 262), (420, 262); 2 reads";
  ]

let zone_cases =
  [
    case "the rocks are in the zone"
      (fun () -> string_of_bool (Wild_zone_one.pin_in_zone (p 476. 224.)))
      "true";
    case "Weedle's (402, 230) is in the zone, off the map's centre"
      (fun () -> string_of_bool (Wild_zone_one.pin_in_zone (p 402. 230.)))
      "true";
    case "the map's centre is not"
      (fun () -> string_of_bool (Wild_zone_one.pin_in_zone (p 401. 224.)))
      "false";
  ]

let () =
  Table_test.run "plza_map_leg" (leg_cases @ exit_cases @ out_cases @ zone_cases)
