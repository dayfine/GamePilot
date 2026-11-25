(* 03.08's and 03.08a's catches (Plza_story.Zone_catch) on a scripted
   console: the party count decides the spot, the map's pin leads there, the
   sweep locks on, the plate is read under held ZL and the throw keeps ZL
   held from the lock to the ball. *)

module L = Plza_story.Look
module P = Plza_story.Catch_plan
module W = Plza_walk.Wild_zone_one
module C = Plza_fake_console.Fake_console

let case name input expectation = { Table_test.name; input; expectation }
let pressed b (i : C.input) = List.mem b i.buttons

let count b (c : C.t) =
  List.length
    (List.filter (fun i -> i.C.at_ms <= c.now && pressed b i) c.inputs)

let last_press b (c : C.t) =
  List.find_map
    (fun (i : C.input) ->
      if i.at_ms <= c.now && pressed b i then Some i.at_ms else None)
    c.inputs

let map_open c =
  match (last_press Wire.Plus c, last_press Wire.B c) with
  | Some s, Some b -> s > b
  | Some _, None -> true
  | None, _ -> false

(* The pin at each map read (from 1), and where the walk heads from there. *)
type route = {
  pins : (float * float) list;
  heading_to : Plza_walk.Map_leg.point list;
}

let pt (x, y) : Plza_walk.Map_leg.point = { x; y }
let nth_clamped l n = List.nth l (max 0 (min (List.length l - 1) n))

(* The zone: the map shows the pin of its read; closed, the minimap arrow
   points at the next waypoint. At the last pin with ZL pressed since the map
   closed, the move symbols show and a plate is locked; ZR throws, and the
   party bar then counts [party + 1] when [catches]. *)
type zone = {
  route : route;
  party : int;
  catches : bool;
  plate_y : float;
  locks : bool;
}

let opens c = count Wire.Plus c
let at_spot z c = opens c >= List.length z.route.pins && not (map_open c)

let zl_since_map c =
  match (last_press Wire.ZL c, last_press Wire.B c) with
  | Some zl, Some b -> zl > b
  | _ -> false

let thrown c = count Wire.ZR c > 0

let screen z (c : C.t) =
  let look = { (L.empty ~at_ms:c.now) with party_bar = true } in
  let k = opens c - 1 in
  if map_open c then
    let x, y = nth_clamped z.route.pins k in
    { look with map_pin = Some { L.x; y } }
  else
    let here = pt (nth_clamped z.route.pins k) in
    let arrow =
      Plza_walk.Map_leg.bearing here (nth_clamped z.route.heading_to k)
    in
    let locked = z.locks && at_spot z c && zl_since_map c && not (thrown c) in
    {
      look with
      minimap_arrow = Some arrow;
      moves = (if locked then [ Some L.Effective ] else []);
    }

let lock z c =
  if z.locks && at_spot z c && zl_since_map c && not (thrown c) then
    Some { P.x = 0.5; y = z.plate_y; caught = Some false }
  else None

let party z c = Some (if z.catches && thrown c then z.party + 1 else z.party)

let to_spot_100 =
  {
    pins = [ (476., 224.); (470., 226.); (456., 231.); (442., 227.) ];
    heading_to =
      [ W.road_entry.pin; W.road_entry.pin; W.spot_100.pin; W.spot_100.pin ];
  }

let to_spot_80 =
  {
    pins = [ (442., 227.); (408., 234.) ];
    heading_to = [ W.spot_80.pin; W.spot_80.pin ];
  }

let zone ?(route = to_spot_100) ?(party = 3) ?(catches = true) ?(plate_y = 0.5)
    ?(locks = true) () =
  { route; party; catches; plate_y; locks }

(* The buttons of each input from the last one without ZL before the throw
   up to the throw's aim: ZL held throughout when every one has it. *)
let zl_run (c : C.t) =
  let inputs = List.rev c.inputs in
  let rec upto_aim acc = function
    | [] -> List.rev acc
    | (i : C.input) :: rest ->
        if pressed Wire.ZR i then List.rev (i :: acc)
        else upto_aim (i :: acc) rest
  in
  let before = upto_aim [] inputs in
  let rec since_gap acc = function
    | [] -> acc
    | (i : C.input) :: rest ->
        if pressed Wire.ZL i then since_gap (i :: acc) rest else acc
  in
  let run = since_gap [] (List.rev before) in
  Printf.sprintf "%d inputs with ZL up to the throw, all ZL: %b"
    (List.length run)
    (List.for_all (pressed Wire.ZL) run)

let run ?(lines = fun l -> String.starts_with ~prefix:"[PLZA] catch_in_zone" l)
    z () =
  let c = C.create () in
  let steps = C.steps ~party:(party z) ~lock:(lock z) c (screen z) in
  let r = Plza_story.Zone_catch.run steps ~max_throws:12 in
  String.concat "\n"
    ((match r with
     | Ok () -> "ok"
     | Error e -> Engine_run.Failure.cause_to_string e)
     :: List.filter lines (C.lines c)
    @ [ zl_run c ])

let cases =
  [
    case
      "03.08: from the rocks to the 100 spot, locked on, caught on the first \
       throw"
      (run (zone ()))
      "ok\n\
       [PLZA] catch_in_zone: the party bar shows 3 filled slots, steady after \
       13 looks\n\
       [PLZA] catch_in_zone: at the start, Taunie's rocks is put at (476, 224) \
       on the map\n\
       [PLZA] catch_in_zone: pin at the start (476, 224): off the rocks to the \
       spot\n\
       [PLZA] catch_in_zone: at the 100 spot: the move symbols showed 73 ms \
       into the lock-on sweep: locked on\n\
       [PLZA] catch_in_zone: target 0: plate at (0.50, 0.50), not caught\n\
       [PLZA] catch_in_zone: target 1: plate at (0.50, 0.50), not caught\n\
       [PLZA] catch_in_zone: choosing target 0 of 1: 0 flicks right\n\
       [PLZA] catch_in_zone: after 0 steps toward the target: plate at (0.50, \
       0.50), not caught\n\
       [PLZA] catch_in_zone: party bar reached 4: yes\n\
       [PLZA] catch_in_zone: throw 1 at plate y 0.50: caught (party 4)\n\
       [PLZA] catch_in_zone: caught at the 100 spot\n\
       [PLZA] catch_in_zone: 1 throws at the 100 spot, caught=true, \
       party_slots=4/4: done\n\
       6 inputs with ZL up to the throw, all ZL: true";
    case "03.08 off the rocks: rocks_not_left, nothing thrown"
      (run (zone ~route:{ to_spot_100 with pins = [ (442., 227.) ] } ()))
      "rocks_not_left: the pin at the start was (442, 227), not within 8 of \
       (476, 224)\n\
       [PLZA] catch_in_zone: the party bar shows 3 filled slots, steady after \
       13 looks\n\
       [PLZA] catch_in_zone: at the start, Taunie's rocks is put at (476, 224) \
       on the map\n\
       [PLZA] catch_in_zone: pin at the start (442, 227), not within 8 of \
       (476, 224): stop\n\
       0 inputs with ZL up to the throw, all ZL: true";
    case "03.08a: a party of 4 walks to the 80 spot for the fifth"
      (run (zone ~route:to_spot_80 ~party:4 ()))
      "ok\n\
       [PLZA] catch_in_zone: the party bar shows 4 filled slots, steady after \
       13 looks\n\
       [PLZA] catch_in_zone: party holds 4 species: walking to the 80 spot for 5\n\
       [PLZA] catch_in_zone: at the 80 spot: the move symbols showed 73 ms \
       into the lock-on sweep: locked on\n\
       [PLZA] catch_in_zone: target 0: plate at (0.50, 0.50), not caught\n\
       [PLZA] catch_in_zone: target 1: plate at (0.50, 0.50), not caught\n\
       [PLZA] catch_in_zone: choosing target 0 of 1: 0 flicks right\n\
       [PLZA] catch_in_zone: after 0 steps toward the target: plate at (0.50, \
       0.50), not caught\n\
       [PLZA] catch_in_zone: party bar reached 5: yes\n\
       [PLZA] catch_in_zone: throw 1 at plate y 0.50: caught (party 5)\n\
       [PLZA] catch_in_zone: caught at the 80 spot\n\
       [PLZA] catch_in_zone: 1 throws at the 80 spot, caught=true, \
       party_slots=5/5: done\n\
       6 inputs with ZL up to the throw, all ZL: true";
    case
      "03.08, a far plate (y 0.40): 4 steps toward it under ZL, then the throw"
      (run (zone ~plate_y:0.40 ()))
      "ok\n\
       [PLZA] catch_in_zone: the party bar shows 3 filled slots, steady after \
       13 looks\n\
       [PLZA] catch_in_zone: at the start, Taunie's rocks is put at (476, 224) \
       on the map\n\
       [PLZA] catch_in_zone: pin at the start (476, 224): off the rocks to the \
       spot\n\
       [PLZA] catch_in_zone: at the 100 spot: the move symbols showed 73 ms \
       into the lock-on sweep: locked on\n\
       [PLZA] catch_in_zone: target 0: plate at (0.50, 0.40), not caught\n\
       [PLZA] catch_in_zone: target 1: plate at (0.50, 0.40), not caught\n\
       [PLZA] catch_in_zone: choosing target 0 of 1: 0 flicks right\n\
       [PLZA] catch_in_zone: after 4 steps toward the target: plate at (0.50, \
       0.40), not caught\n\
       [PLZA] catch_in_zone: party bar reached 4: yes\n\
       [PLZA] catch_in_zone: throw 1 at plate y 0.40: caught (party 4)\n\
       [PLZA] catch_in_zone: caught at the 100 spot\n\
       [PLZA] catch_in_zone: 1 throws at the 100 spot, caught=true, \
       party_slots=4/4: done\n\
       14 inputs with ZL up to the throw, all ZL: true";
    case
      "03.08, the plate gone after a miss: called caught, the bar says 3: \
       short_of_species"
      (run (zone ~catches:false ()))
      "short_of_species: the party holds 3 species of 4 (1 throws at the 100 \
       spot)\n\
       [PLZA] catch_in_zone: the party bar shows 3 filled slots, steady after \
       13 looks\n\
       [PLZA] catch_in_zone: at the start, Taunie's rocks is put at (476, 224) \
       on the map\n\
       [PLZA] catch_in_zone: pin at the start (476, 224): off the rocks to the \
       spot\n\
       [PLZA] catch_in_zone: at the 100 spot: the move symbols showed 73 ms \
       into the lock-on sweep: locked on\n\
       [PLZA] catch_in_zone: target 0: plate at (0.50, 0.50), not caught\n\
       [PLZA] catch_in_zone: target 1: plate at (0.50, 0.50), not caught\n\
       [PLZA] catch_in_zone: choosing target 0 of 1: 0 flicks right\n\
       [PLZA] catch_in_zone: after 0 steps toward the target: plate at (0.50, \
       0.50), not caught\n\
       [PLZA] catch_in_zone: party bar reached 4: no\n\
       [PLZA] catch_in_zone: throw 1 at plate y 0.50: caught\n\
       [PLZA] catch_in_zone: caught at the 100 spot\n\
       [PLZA] catch_in_zone: the party bar shows 3 filled slots, steady after \
       13 looks\n\
       [PLZA] catch_in_zone: 1 throws at the 100 spot, caught=true, \
       party_slots=3/4: short\n\
       6 inputs with ZL up to the throw, all ZL: true";
    case "03.08, nothing locks on in the sweep: short_of_species, no throws"
      (run (zone ~locks:false ()))
      "short_of_species: the party holds 3 species of 4 (0 throws at the 100 \
       spot)\n\
       [PLZA] catch_in_zone: the party bar shows 3 filled slots, steady after \
       13 looks\n\
       [PLZA] catch_in_zone: at the start, Taunie's rocks is put at (476, 224) \
       on the map\n\
       [PLZA] catch_in_zone: pin at the start (476, 224): off the rocks to the \
       spot\n\
       [PLZA] catch_in_zone: at the 100 spot: no move symbols in 8 sweep \
       rounds (19184 ms): L\n\
       [PLZA] catch_in_zone: no lock-on at the 100 spot in the sweep\n\
       [PLZA] catch_in_zone: 0 throws at the 100 spot, caught=false, \
       party_slots=3/4: short\n\
       0 inputs with ZL up to the throw, all ZL: true";
    case "a party of 5: nothing to catch"
      (run (zone ~party:5 ()))
      "ok\n\
       [PLZA] catch_in_zone: the party bar shows 5 filled slots, steady after \
       13 looks\n\
       [PLZA] catch_in_zone: the party already holds 5 species: nothing to catch\n\
       0 inputs with ZL up to the throw, all ZL: true";
  ]

let () = Table_test.run "plza_zone_catch" cases
