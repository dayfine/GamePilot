(* FireRed's tables in the plan expansion: a place on another floor of the
   Dept. Store is reached by the lift, from inside the store or outside it;
   heal_at looks its town's nurse up in the towns. *)

let plan_text ~start events =
  Printf.sprintf
    {|{"format": "gamepilot-checkpoint/1", "game": "frlg",
       "checkpoint": {"id": "t", "title": "t", "start": %s, "events": [%s]},
       "execution": {}}|}
    start
    (String.concat ", " events)

let route id place =
  Printf.sprintf
    {|{"id": "%s", "kind": "route", "action": "run", "args": {"target": {"place": "%s"}}}|}
    id place

let at_1f =
  {|{"map": "CeladonCity_DepartmentStore_1F", "tiles": [[6, 2]], "facing": "south"}|}

let outside = {|{"map": "CeladonCity", "tiles": [[48, 12]], "facing": "south"}|}

let expanded ~start events () =
  match
    Frlg_checkpoints.Plan_file.decode ~source:"t"
      (Yojson.Safe.from_string (plan_text ~start events))
  with
  | Ok p ->
      String.concat "\n"
        (List.map Pokemon_engine.Plan_text.event p.checkpoint.events)
  | Error e -> e

let up_to_4f =
  "clerk: [run] route to CeladonCity_DepartmentStore_1F (6, 2) north\n\
   clerk.lift: [lift_floor] game_action {\"from\":\"1F\",\"to\":\"4F\"} => \
   CeladonCity_DepartmentStore_4F (6, 2) south\n\
   clerk.walk: [run] route to CeladonCity_DepartmentStore_4F (3, 11) south"

let heal_at town =
  Printf.sprintf
    {|{"id": "heal", "fragment": "heal_at", "args": {"town": "%s"}, "why": "full HP"}|}
    town

let lavender = {|{"map": "LavenderTown", "tiles": [[6, 6]], "facing": "south"}|}
let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "plan_expansion"
    [
      case "a place on the floor the player is on: one route"
        (expanded ~start:at_1f [ route "save" "celadon_dept_store_1f_save" ])
        "save: [run] route to CeladonCity_DepartmentStore_1F (6, 2) south";
      case "a place on another floor: to the lift, the ride, the walk"
        (expanded ~start:at_1f [ route "clerk" "celadon_dept_store_4f_clerk" ])
        up_to_4f;
      case "from outside the store: the same, from 1F's lift"
        (expanded ~start:outside
           [ route "clerk" "celadon_dept_store_4f_clerk" ])
        up_to_4f;
      case "from 4F to outside: down to 1F first"
        (expanded ~start:at_1f
           [
             route "clerk" "celadon_dept_store_4f_clerk";
             route "out" "celadon_dept_store_west_door_outside";
           ])
        (up_to_4f
       ^ "\n\
          out: [run] route to CeladonCity_DepartmentStore_4F (6, 2) north\n\
          out.lift: [lift_floor] game_action {\"from\":\"4F\",\"to\":\"1F\"} \
          => CeladonCity_DepartmentStore_1F (6, 2) south\n\
          out.walk: [run] route to CeladonCity (11, 15) south");
      case "a ride that lets the player out on the place: no walk"
        (expanded ~start:at_1f
           [
             route "clerk" "celadon_dept_store_4f_clerk";
             route "down" "celadon_dept_store_1f_save";
           ])
        (up_to_4f
       ^ "\n\
          down: [run] route to CeladonCity_DepartmentStore_4F (6, 2) north\n\
          down.lift: [lift_floor] game_action {\"from\":\"4F\",\"to\":\"1F\"} \
          => CeladonCity_DepartmentStore_1F (6, 2) south");
      case "heal_at: the walk to the town's nurse, then the heal"
        (expanded ~start:lavender [ heal_at "lavender" ])
        "heal.walk: [run] route to LavenderTown_PokemonCenter_1F (7, 4) north\n\
         heal: heal";
      case "heal_at an unknown town suggests the nearest"
        (expanded ~start:lavender [ heal_at "lavendar" ])
        "t: checkpoint.events[0]: no town \"lavendar\"; did you mean lavender?";
    ];
  let open Grid_geometry in
  let module PE = Pokemon_engine.Plan in
  let decode_events ~start events =
    match
      Frlg_checkpoints.Plan_file.decode ~source:"t"
        (Yojson.Safe.from_string (plan_text ~start events))
    with
    | Ok p -> Ok p.checkpoint.events
    | Error e -> Error e
  in
  let show_item (id, kind, way) =
    let k =
      match kind with
      | `Route (m, ts, f) ->
          Printf.sprintf "Route(%s, [%s], %s)" m
            (String.concat ";" (List.map Tile_pos.to_string ts))
            (Option.fold ~none:"none" ~some:Direction.name f)
      | `Heal -> "Heal"
      | `Action args -> "Action(" ^ Yojson.Safe.to_string (`Assoc args) ^ ")"
      | `Other -> "Other"
    in
    Printf.sprintf "(%s, %s, %s)" id k (Option.value ~default:"None" way)
  in
  let show_res show_ok = function
    | Ok xs -> "Ok [\n  " ^ String.concat ";\n  " (List.map show_ok xs) ^ "\n]"
    | Error e -> "Error " ^ e
  in
  let check_eq ~show name expected actual =
    if expected <> actual then (
      Printf.eprintf "FAIL plan_expansion: %s\nexpected: %s\nactual:   %s\n%!"
        name (show expected) (show actual);
      exit 1)
  in
  let show_id_way (id, way) =
    Printf.sprintf "(%s, %s)" id (Option.value ~default:"None" way)
  in
  let summarize (e : PE.event) =
    match e.kind with
    | PE.Game (Route { target = { map; tiles; facing }; _ }) ->
        (e.id, `Route (map, tiles, facing), e.way)
    | PE.Game Heal -> (e.id, `Heal, e.way)
    | PE.Named_action args -> (e.id, `Action args, e.way)
    | _ -> (e.id, `Other, e.way)
  in
  let outdoors = {|{"anywhere": "outdoors"}|} in
  let grass_call =
    {|{"id": "ekans", "fragment": "wild_rng_grass_catch",
       "args": {"town": "route10", "spot": "route10_north_grass",
                "location": "route_10", "species": "ekans"}}|}
  in
  let grass_events =
    Result.map (List.map summarize)
      (decode_events ~start:outdoors [ grass_call ])
  in
  check_eq ~show:(show_res show_item)
    "wild_rng_grass_catch expands to 10 typed events"
    (Ok
       [
         ("ekans.fly", `Action [ ("town", `String "Route10") ], Some "fly");
         ( "ekans.to_spot",
           `Route
             ("Route10", [ { Tile_pos.x = 12; y = 8 } ], Some Direction.East),
           Some "run" );
         ("ekans.save_before", `Action [], Some "save_game");
         ( "ekans.catch",
           `Action
             [
               ("method", `String "grass");
               ("species", `String "ekans");
               ("location", `String "route_10");
             ],
           Some "wild_rng" );
         ("ekans.save_catch", `Action [], Some "save_game");
         ( "ekans.to_pc",
           `Route
             ( "Route10_PokemonCenter_1F",
               [ { Tile_pos.x = 11; y = 2 } ],
               Some Direction.North ),
           Some "run" );
         ( "ekans.deposit",
           `Action [ ("species", `List [ `String "ekans" ]) ],
           Some "pc_deposit" );
         ( "ekans.to_nurse",
           `Route
             ( "Route10_PokemonCenter_1F",
               [ { Tile_pos.x = 7; y = 4 } ],
               Some Direction.North ),
           Some "run" );
         ("ekans.heal", `Heal, None);
         ( "ekans.outside",
           `Route
             ("Route10", [ { Tile_pos.x = 13; y = 21 } ], Some Direction.South),
           Some "run" );
       ])
    grass_events;
  let surf_call =
    {|{"id": "psyduck", "fragment": "wild_rng_surf_catch",
       "args": {"town": "vermilion", "shore": "vermilion_center_outside",
                "location": "viridian_city", "species": "psyduck"}}|}
  in
  let surf_ids =
    Result.map
      (List.map (fun (e : PE.event) -> (e.id, e.way)))
      (decode_events ~start:outdoors [ surf_call ])
  in
  check_eq ~show:(show_res show_id_way)
    "wild_rng_surf_catch includes surf and wild_rng"
    (Ok
       [
         ("psyduck.fly", Some "fly");
         ("psyduck.to_shore", Some "run");
         ("psyduck.surf", Some "surf");
         ("psyduck.save_before", Some "save_game");
         ("psyduck.catch", Some "wild_rng");
         ("psyduck.save_catch", Some "save_game");
         ("psyduck.to_pc", Some "run");
         ("psyduck.deposit", Some "pc_deposit");
         ("psyduck.to_nurse", Some "run");
         ("psyduck.heal", None);
         ("psyduck.outside", Some "run");
       ])
    surf_ids;
  let fish_call =
    {|{"id": "shellder", "fragment": "wild_rng_fish_catch",
       "args": {"town": "vermilion", "shore": "vermilion_center_outside",
                "location": "vermilion_city", "species": "shellder"}}|}
  in
  let fish_ids =
    Result.map
      (List.map (fun (e : PE.event) -> (e.id, e.way)))
      (decode_events ~start:outdoors [ fish_call ])
  in
  check_eq ~show:(show_res show_id_way)
    "wild_rng_fish_catch expands to 10 events"
    (Ok
       [
         ("shellder.fly", Some "fly");
         ("shellder.to_shore", Some "run");
         ("shellder.save_before", Some "save_game");
         ("shellder.catch", Some "wild_rng");
         ("shellder.save_catch", Some "save_game");
         ("shellder.to_pc", Some "run");
         ("shellder.deposit", Some "pc_deposit");
         ("shellder.to_nurse", Some "run");
         ("shellder.heal", None);
         ("shellder.outside", Some "run");
       ])
    fish_ids;
  let gift_call =
    {|{"id": "scyther", "fragment": "gift_rng_prize",
       "args": {"town": "vermilion", "counter": "celadon_prize_room_mon_clerk",
                "species": "scyther", "prize_row": "3"}}|}
  in
  let gift_ids =
    Result.map
      (List.map (fun (e : PE.event) -> (e.id, e.way)))
      (decode_events ~start:outdoors [ gift_call ])
  in
  check_eq ~show:(show_res show_id_way) "gift_rng_prize expands to 8 events"
    (Ok
       [
         ("scyther.fly", Some "fly");
         ("scyther.to_counter", Some "run");
         ("scyther.save_before", Some "save_game");
         ("scyther.claim", Some "gift_rng");
         ("scyther.save_claim", Some "save_game");
         ("scyther.to_pc", Some "run");
         ("scyther.deposit", Some "pc_deposit");
         ("scyther.outside", Some "run");
       ])
    gift_ids;
  let bad_spot =
    {|{"id": "ekans", "fragment": "wild_rng_grass_catch",
       "args": {"town": "route10", "spot": "route10_north_gras",
                "location": "route_10", "species": "ekans"}}|}
  in
  check_eq
    ~show:(show_res (fun (e : PE.event) -> e.id))
    "unknown place arg fails with suggestion"
    (Error
       "t: checkpoint.events[0]: no place \"route10_north_gras\"; did you mean \
        route10_north_grass?")
    (decode_events ~start:outdoors [ bad_spot ])
