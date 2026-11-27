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

(* Every town's nurse, mart, pc and outside places are named with its key: one
   spelling per town. *)
let towns_prefix () =
  let towns = Towns.towns (Place_table.towns table) in
  let named (t : Towns.town) place =
    String.starts_with ~prefix:(t.key ^ "_") place
  in
  let wrong (t : Towns.town) =
    let places =
      (t.nurse :: Option.to_list t.mart)
      @ Option.to_list t.pc @ Option.to_list t.outside
    in
    List.filter (fun p -> not (named t p)) places
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

let center_nurse name () =
  match Place_table.center_nurse table name with
  | Ok g -> Pokemon_engine.Pose.to_string (Grid g)
  | Error e -> e

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "places"
    [
      case "every place's object is in the maps, usable from its stand tile"
        (fun () -> failures resolves)
        "48 places, all pass";
      case "every place's stand tile is walked to from a warp"
        (fun () -> failures reachable)
        "48 places, all pass";
      case "every town's Fly name is one Fly knows" towns_fly
        "12 towns, all pass";
      case "every town's nurse and mart start with the town's key" towns_prefix
        "12 towns, all pass";
      case "a town's nurse pose by Fly name"
        (center_nurse "LavenderTown")
        "LavenderTown_PokemonCenter_1F (7, 4) north";
      case "Indigo Plateau's nurse pose by key (non-standard layout)"
        (center_nurse "indigo_plateau")
        "IndigoPlateau_PokemonCenter_1F (13, 12) north";
      case "Center map of a Fly town with no Center"
        (fun () ->
          Option.value ~default:"none"
            (Place_table.center_map_of_fly table "PalletTown"))
        "none";
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
    ];
  let resolve = Place_table.resolve table in
  let check_res name expected actual =
    if expected <> actual then (
      Printf.eprintf "FAIL %s\n%!" name;
      exit 1)
  in
  check_res "town.pc resolves" (Ok "route10_center_pc")
    (resolve ~kind:"town" "route10" ~field:(Some "pc"));
  check_res "town.outside resolves" (Ok "route10_center_outside")
    (resolve ~kind:"town" "route10" ~field:(Some "outside"));
  check_res "celadon.pc resolves" (Ok "celadon_center_pc")
    (resolve ~kind:"town" "celadon" ~field:(Some "pc"));
  check_res "celadon.outside resolves" (Ok "celadon_center_outside")
    (resolve ~kind:"town" "celadon" ~field:(Some "outside"));
  check_res "saffron.pc resolves" (Ok "saffron_center_pc")
    (resolve ~kind:"town" "saffron" ~field:(Some "pc"));
  check_res "saffron.outside resolves" (Ok "saffron_center_outside")
    (resolve ~kind:"town" "saffron" ~field:(Some "outside"));
  check_res "lavender.pc resolves" (Ok "lavender_center_pc")
    (resolve ~kind:"town" "lavender" ~field:(Some "pc"));
  check_res "lavender.outside resolves" (Ok "lavender_center_outside")
    (resolve ~kind:"town" "lavender" ~field:(Some "outside"));
  check_res "viridian.pc resolves" (Ok "viridian_center_pc")
    (resolve ~kind:"town" "viridian" ~field:(Some "pc"));
  check_res "viridian.outside resolves" (Ok "viridian_center_outside")
    (resolve ~kind:"town" "viridian" ~field:(Some "outside"));
  check_res "town without pc errors" (Error "pewter has no pc place")
    (resolve ~kind:"town" "pewter" ~field:(Some "pc"));
  check_res "place resolves valid place" (Ok "route10_north_grass")
    (resolve ~kind:"place" "route10_north_grass" ~field:None);
  check_res "place rejects field" (Error "a place has no pc")
    (resolve ~kind:"place" "route10_north_grass" ~field:(Some "pc"));
  check_res "string passes through" (Ok "growlithe")
    (resolve ~kind:"string" "growlithe" ~field:None);
  check_res "string rejects field" (Error "a string has no fly")
    (resolve ~kind:"string" "growlithe" ~field:(Some "fly"))
