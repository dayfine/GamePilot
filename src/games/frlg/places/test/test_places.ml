(* The places table against PokemonSimulation's maps: every place's object is
   there and usable from its stand tile, and its stand tile is walked to from a
   warp of its map or of a map it joins. *)

open Frlg_places
module Run = Frlg_checkpoints.Checkpoint_run

let table = Result.get_ok (Place_table.load ())
let map = Run.load_map
let world = lazy (Result.get_ok (Run.load_world ()))
let places = Place_table.places table

let failures check =
  match List.filter_map check places with
  | [] -> Printf.sprintf "%d places, all pass" (List.length places)
  | l -> String.concat "; " l

let resolves (p : Place_table.place) =
  match Result.bind (map p.map) (fun m -> Place_objects.check m p) with
  | Ok () -> None
  | Error e -> Some (p.name ^ ": " ^ e)

let warp_tiles name =
  match map name with
  | Error _ -> []
  | Ok (m : Grid_maps.Map_data.t) ->
      List.map
        (fun (w : Grid_maps.Map_features.warp) -> (name, w.warp_pos))
        m.warps

(* Where walks to the place may start: its map's warps, then those of the maps
   it joins (a route split by a Cut tree is reached from its other side). *)
let entrances name =
  let joined =
    match map name with
    | Ok m ->
        List.map
          (fun (c : Grid_maps.Map_features.connection) -> c.connected_map)
          m.connections
    | Error _ -> []
  in
  warp_tiles name @ List.concat_map warp_tiles joined

let walk_from world (p : Place_table.place) (at_map, at_tile) =
  let s = Place_table.spot p in
  Result.bind
    (Frlg_overworld.Route_target.place_of world
       { at_map; at_tile; faces = None })
    (fun from ->
      Frlg_overworld.Route_target.plan world ~from ~facing:None
        { map = s.map; tiles = [ s.tile ]; facing = s.facing })

let reachable (p : Place_table.place) =
  let world = Lazy.force world in
  if List.exists (fun e -> Result.is_ok (walk_from world p e)) (entrances p.map)
  then None
  else Some (p.name ^ ": no walk from a warp of its map or the maps it joins")

(* Every town's Fly name is a town Fly knows. *)
let towns_fly () =
  let fly = Result.get_ok (Frlg_actions.Fly_towns.load ()) in
  let towns = Towns.towns (Place_table.towns table) in
  match
    List.filter
      (fun (t : Towns.town) -> Frlg_actions.Fly_towns.find fly t.fly = None)
      towns
  with
  | [] -> Printf.sprintf "%d towns, all pass" (List.length towns)
  | l ->
      String.concat ", "
        (List.map (fun (t : Towns.town) -> t.key ^ ": " ^ t.fly) l)

(* Every town's nurse and mart places are named with its key: one spelling per
   town. *)
let towns_prefix () =
  let towns = Towns.towns (Place_table.towns table) in
  let named (t : Towns.town) place =
    String.starts_with ~prefix:(t.key ^ "_") place
  in
  let wrong (t : Towns.town) =
    List.filter (fun p -> not (named t p)) (t.nurse :: Option.to_list t.mart)
  in
  match List.concat_map wrong towns with
  | [] -> Printf.sprintf "%d towns, all pass" (List.length towns)
  | l -> String.concat ", " l

let find name () =
  match Place_table.find table name with
  | Ok p ->
      let s = Place_table.spot p in
      Printf.sprintf "%s %s" s.map (Grid_geometry.Tile_pos.to_string s.tile)
  | Error e -> e

let parse text () =
  match Place_table.parse ~source:"t.json" (Yojson.Safe.from_string text) with
  | Ok t -> string_of_int (List.length (Place_table.places t)) ^ " places"
  | Error e -> e

let one_place place =
  Printf.sprintf
    {|{"format": "gamepilot-places/1", "game": "frlg", "places": {"a": %s}}|}
    place

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "places"
    [
      case "every place's object is in the maps, usable from its stand tile"
        (fun () -> failures resolves)
        "15 places, all pass";
      case "every place's stand tile is walked to from a warp"
        (fun () -> failures reachable)
        "15 places, all pass";
      case "every town's Fly name is one Fly knows" towns_fly
        "2 towns, all pass";
      case "every town's nurse and mart start with the town's key" towns_prefix
        "2 towns, all pass";
      case "a town whose nurse is not a place"
        (parse
           {|{"format": "gamepilot-places/1", "game": "frlg", "places": {},
              "towns": {"x": {"nurse": "x_nurse", "fly": "X"}}}|})
        "t.json: towns.x.nurse x_nurse is not a place of the table.";
      case "a place's spot"
        (find "celadon_dept_store_4f_clerk")
        "CeladonCity_DepartmentStore_4F (3, 11)";
      case "a misspelt place suggests the nearest"
        (find "celadon_dept_store_4f_clrk")
        "no place \"celadon_dept_store_4f_clrk\"; did you mean \
         celadon_dept_store_4f_clerk?";
      case "a place with no object in the maps says what it is"
        (parse
           (one_place
              {|{"map": "M", "object": {"not_in_maps": "a save spot"}, "stand": [1, 2], "facing": "south"}|}))
        "1 places";
      case "an object of an unknown kind"
        (parse
           (one_place
              {|{"map": "M", "object": {"sign": "s"}, "stand": [1, 2], "facing": "south"}|}))
        "t.json: places.a.object.names none of npc, item, hidden_item, warp, \
         not_in_maps first.";
      case "a stand tile that is not [x, y]"
        (parse
           (one_place
              {|{"map": "M", "object": {"npc": "s"}, "stand": [1], "facing": "south"}|}))
        "t.json: places.a.stand is not [x, y].";
    ]
