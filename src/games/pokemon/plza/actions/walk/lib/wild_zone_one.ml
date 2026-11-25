open Map_leg

let catch_stop_radius = 12.

let rocks =
  { name = "Taunie's rocks"; pin = { x = 476.; y = 224. }; stop_radius = 0. }

(* The road below the rocks. Going straight from the rocks to the 100 spot
   stops on an obstacle at about (467, 226) 3 runs in 5 (2026-11-18/19);
   through here the heading to the spot keeps south of it. The fork keeps it
   in PokemonLZA_AutoStoryCatches.cpp. *)
let road_entry =
  { name = "the road entry"; pin = { x = 456.; y = 231. }; stop_radius = 0. }

let spot_100 =
  {
    name = "the 100 spot";
    pin = { x = 442.; y = 227. };
    stop_radius = catch_stop_radius;
  }

let spot_80 =
  {
    name = "the 80 spot";
    pin = { x = 408.; y = 234. };
    stop_radius = catch_stop_radius;
  }

(* Clockwise from its north west corner. *)
let outline =
  [
    { x = 281.; y = 199. };
    { x = 506.; y = 199. };
    { x = 515.; y = 218. };
    { x = 510.; y = 226. };
    { x = 500.; y = 230. };
    { x = 450.; y = 248. };
    { x = 400.; y = 260. };
    { x = 370.; y = 265. };
    { x = 359.; y = 264. };
    { x = 357.; y = 248. };
    { x = 281.; y = 249. };
  ]

let map_centre = { x = 401.; y = 224. }
let map_centre_radius = 3.

let at_map_centre p =
  Float.hypot (p.x -. map_centre.x) (p.y -. map_centre.y) <= map_centre_radius

(* Even-odd rule: does the edge from [a] to [b] cross the ray east of [p]? *)
let crosses p (a, b) =
  a.y > p.y <> (b.y > p.y)
  && p.x < a.x +. ((p.y -. a.y) *. (b.x -. a.x) /. (b.y -. a.y))

let edges = function
  | [] -> []
  | first :: _ as points ->
      let rec pairs = function
        | a :: (b :: _ as rest) -> (a, b) :: pairs rest
        | [ last ] -> [ (last, first) ]
        | [] -> []
      in
      pairs points

let inside p = List.length (List.filter (crosses p) (edges outline)) mod 2 = 1
let pin_in_zone p = (not (at_map_centre p)) && inside p
let gate_heading = 270.
let gate_heading_tolerance = 8.

(* 1 north of the (361, 253) read, as runs with no prompt ended at y 255 on
   the left pillar. *)
let far_gate = { x = 361.; y = 252. }

(* Just east of the gate on its centre line: any point in the zone runs
   straight to it, then straight west between the pillars. *)
let gate_run_up = { x = 375.; y = 252. }

let exit_legs start =
  if
    start.x > far_gate.x
    && Float.abs (bearing start far_gate -. gate_heading)
       <= gate_heading_tolerance
  then [ far_gate ]
  else [ gate_run_up; far_gate ]

let out_of_zone_reads = 2
let point_text p = Printf.sprintf "(%.0f, %.0f)" p.x p.y

let unread read before =
  let before =
    if before = [] then ""
    else
      Printf.sprintf " (before: %s)"
        (String.concat ", " (List.rev_map point_text before))
  in
  Engine_run.Failure.cause "zone_unread"
    (Printf.sprintf
       "out of Wild Zone 1 not known: no map pin on read %d of %d%s" read
       out_of_zone_reads before)

let reads_text reads = String.concat ", " (List.rev_map point_text reads)

let in_zone at before =
  Engine_run.Failure.cause "in_wild_zone"
    ("still in Wild Zone 1: the map pin reads " ^ reads_text (at :: before))

let check_out pin =
  let rec go read before =
    let next at =
      if pin_in_zone at then Error (in_zone at before)
      else if at_map_centre at || read >= out_of_zone_reads then
        Ok (reads_text (at :: before))
      else go (read + 1) (at :: before)
    in
    match pin () with None -> Error (unread read before) | Some at -> next at
  in
  go 1 []
