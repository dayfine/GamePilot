(* The places table against PokemonSimulation's maps: every place's object is
   there and usable from its stand tile, and its stand tile is walked to from
   a warp of the map or of a map it joins. *)

open Frlg_places

let table = Result.get_ok (Place_table.load ())
let world = lazy (Result.get_ok (Frlg_checkpoints.Checkpoint_run.load_world ()))

let failures check =
  match List.filter_map check (Place_table.places table) with
  | [] ->
      Printf.sprintf "%d places, all pass"
        (List.length (Place_table.places table))
  | l -> String.concat "; " l

let resolves (p : Place_table.place) =
  match
    Result.bind (Place_objects.load_map p.map) (fun m ->
        Place_objects.check m p)
  with
  | Ok () -> None
  | Error e -> Some (p.name ^ ": " ^ e)

let fields = function `Assoc f -> f | _ -> []

let warp_tiles map =
  match Place_objects.load_map map with
  | Error _ -> []
  | Ok json -> (
      match List.assoc_opt "warps" (fields json) with
      | Some (`List warps) ->
          List.filter_map
            (fun w ->
              match List.assoc_opt "coord" (fields w) with
              | Some (`List [ `Int x; `Int y ]) ->
                  Some (map, { Grid_maps.Tile_pos.x; y })
              | _ -> None)
            warps
      | _ -> [])

let connected map =
  match Place_objects.load_map map with
  | Error _ -> []
  | Ok json -> (
      match List.assoc_opt "connections" (fields json) with
      | Some (`List l) ->
          List.filter_map
            (fun c ->
              match List.assoc_opt "to_map" (fields c) with
              | Some (`String m) -> Some m
              | _ -> None)
            l
      | _ -> [])

(* Where walks to the place may start: the map's warps, then those of the maps
   it joins (a route split by a Cut tree is reached from its other side). *)
let entrances map = warp_tiles map @ List.concat_map warp_tiles (connected map)

let walk_from world (p : Place_table.place) (at_map, at_tile) =
  Result.bind
    (Frlg_overworld.Route_target.place_of world
       { at_map; at_tile; faces = None })
    (fun from ->
      Frlg_overworld.Route_target.plan world ~from ~facing:None
        (Place_table.pose p))

let reachable (p : Place_table.place) =
  let world = Lazy.force world in
  if List.exists (fun e -> Result.is_ok (walk_from world p e)) (entrances p.map)
  then None
  else Some (p.name ^ ": no walk from a warp of its map or the maps it joins")

let find name () =
  match Place_table.find table name with
  | Ok p -> Checkpoints.Pose.grid_to_string (Place_table.pose p)
  | Error e -> e

let parse text () =
  match Place_table.parse ~source:"t.json" (Yojson.Safe.from_string text) with
  | Ok t -> string_of_int (List.length (Place_table.places t)) ^ " places"
  | Error e -> e

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "places"
    [
      case "every place's object is in the maps, usable from its stand tile"
        (fun () -> failures resolves)
        "17 places, all pass";
      case "every place's stand tile is walked to from a warp"
        (fun () -> failures reachable)
        "17 places, all pass";
      case "a place's pose"
        (find "dept_store_4f_clerk")
        "CeladonCity_DepartmentStore_4F (3, 11) south";
      case "a misspelt place suggests the nearest"
        (find "dept_store_4f_clrk")
        "no place \"dept_store_4f_clrk\"; did you mean dept_store_4f_clerk?";
      case "a name near nothing suggests nothing" (find "pallet_house")
        "no place \"pallet_house\"";
      case "a place with no object in the maps says what it is"
        (parse
           {|{"format": "gamepilot-places/1", "game": "frlg", "places": {
               "a": {"map": "M", "object": {"not_in_maps": "a save spot"},
                     "stand": [1, 2], "facing": "south"}}}|})
        "1 places";
      case "an object of an unknown kind"
        (parse
           {|{"format": "gamepilot-places/1", "game": "frlg", "places": {
               "a": {"map": "M", "object": {"sign": "s"},
                     "stand": [1, 2], "facing": "south"}}}|})
        "t.json: places.a.object.names none of npc, item, hidden_item, warp, \
         not_in_maps first.";
      case "a stand tile that is not [x, y]"
        (parse
           {|{"format": "gamepilot-places/1", "game": "frlg", "places": {
               "a": {"map": "M", "object": {"npc": "s"},
                     "stand": [1], "facing": "south"}}}|})
        "t.json: places.a.stand is not [x, y].";
    ]
