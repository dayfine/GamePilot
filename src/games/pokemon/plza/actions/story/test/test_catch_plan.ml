(* The zone catches' choices, as the C++'s tests check them
   (PokemonLZA_AutoStoryActions_Tests.cpp). *)

open Plza_story.Catch_plan

let case name input expectation = { Table_test.name; input; expectation }
let plate x y : target = { x; y; caught = Some false }

(* Views added before the cycle stopped, its targets, and the flicks to
   target [i]. *)
let cycle_text ~max_views views i () =
  let rec go c added = function
    | [] -> (c, added)
    | v :: rest ->
        let c, more = add c v in
        if more then go c (added + 1) rest else (c, added + 1)
  in
  let c, added = go (cycle ~max_views) 0 views in
  Printf.sprintf "%d views added, %d targets, %d flicks" added
    (List.length (targets c))
    (flicks_to c i)

let cycle_cases =
  [
    case "stops where a flick finds no other, the nearest back left"
      (cycle_text ~max_views:4
         [ plate 0.50 0.25; plate 0.52 0.40; plate 0.48 0.30; plate 0.49 0.31 ]
         1)
      "4 views added, 3 targets, -1 flicks";
    case "stops when it comes round to the first, the second a flick right"
      (cycle_text ~max_views:4
         [ plate 0.50 0.25; plate 0.50 0.40; plate 0.51 0.26 ]
         1)
      "3 views added, 2 targets, 1 flicks";
    case "is bounded by its views, the lock on the last"
      (cycle_text ~max_views:4
         (List.init 7 (fun i ->
              plate (0.1 *. float_of_int i) (0.2 +. (0.05 *. float_of_int i))))
         3)
      "4 views added, 4 targets, 0 flicks";
  ]

let settle reads () =
  let looks = ref 0 in
  let read () =
    let i = !looks in
    incr looks;
    List.nth reads (min i (List.length reads - 1))
  in
  match settled_party_slots read with
  | Some n -> Printf.sprintf "%d after %d looks" n !looks
  | None -> Printf.sprintf "none after %d looks" !looks

let settle_cases =
  [
    case "the last catch joining the bar a second after the first read counts"
      (settle [ Some 4; Some 4; Some 4; Some 4; Some 5 ])
      "5 after 17 looks";
    case "nothing read in 2 s: none" (settle [ None ]) "none after 8 looks";
    case "a count that never holds: the last after 8 s"
      (settle (List.init 32 (fun i -> Some (3 + (i mod 2)))))
      "4 after 32 looks";
  ]

let nearest targets () =
  match nearest_uncaught targets with
  | Some i -> string_of_int i
  | None -> "none"

let choice_cases =
  [
    case "the lowest plate not caught"
      (nearest
         [
           plate 0.3 0.30;
           { (plate 0.5 0.48) with caught = Some true };
           plate 0.6 0.41;
           { (plate 0.7 0.41) with caught = None };
         ])
      "2";
    case "all caught: none"
      (nearest [ { (plate 0.3 0.30) with caught = Some true } ])
      "none";
    case "a far plate: steps before the first throw"
      (fun () ->
        string_of_bool (step_toward (plate 0.5 0.40) ~misses:0 ~steps:3))
      "true";
    case "a far plate after a miss: 2 steps"
      (fun () ->
        string_of_bool (step_toward (plate 0.5 0.40) ~misses:1 ~steps:2))
      "false";
    case "a near plate: no step"
      (fun () ->
        string_of_bool (step_toward (plate 0.5 0.45) ~misses:0 ~steps:0))
      "false";
  ]

let () =
  Table_test.run "plza_catch_plan" (cycle_cases @ settle_cases @ choice_cases)
