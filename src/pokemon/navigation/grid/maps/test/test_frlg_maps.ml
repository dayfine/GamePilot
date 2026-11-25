(* FireRed's runtime maps from the PokemonSimulation submodule: every one
   parses (BDSP's too), and a few read as the decompilation has them (a town and its
   route, a Card Key door, the Mansion's statue switch, a Victory Road
   button). *)

open Grid_maps
open Map_gates

(* third_party/ sits outside the dune project, so find it from the build
   dir. *)
let maps_dir_of game =
  let maps =
    List.fold_left Filename.concat "third_party"
      [ "PokemonSimulation"; "data"; "games"; game; "maps" ]
  in
  let rec up dir =
    let candidate = Filename.concat dir maps in
    if Sys.file_exists candidate then candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then
        failwith "third_party/PokemonSimulation not found above the test dir"
      else up parent
  in
  up (Sys.getcwd ())

let maps_dir = maps_dir_of "frlg"
let load name = Result.get_ok (Map_file.load_runtime ~maps_dir name)

let all_parse maps_dir =
  let names = Map_file.runtime_names ~maps_dir in
  let error name =
    match Map_file.load_runtime ~maps_dir name with
    | Ok _ -> None
    | Error e -> Some e
  in
  let errors = List.filter_map error names in
  match (names, errors) with
  | [], _ -> Error "no runtime maps"
  | _, [] -> Ok ()
  | _, first :: _ ->
      Error
        (Printf.sprintf "%d of %d maps fail; first: %s" (List.length errors)
           (List.length names) first)

let warp_to (map : Map_data.t) x y =
  match Map_data.warp_at map { x; y } with
  | Some { destination = Some { to_map; to_point }; _ } ->
      to_map ^ "." ^ to_point
  | _ -> "(none)"

let gate_of (map : Map_data.t) id = Map_data.String_map.find id map.gates
let switch_of (map : Map_data.t) id = Map_data.String_map.find id map.switches

let size (map : Map_data.t) =
  Printf.sprintf "%dx%d" (Grid.width map.tiles) (Grid.height map.tiles)

let cases : Map_text.case list =
  [
    {
      name = "Pallet Town";
      input = "PalletTown";
      expectation =
        [
          ("size", "24x20", size);
          ( "the player's door",
            "PalletTown_PlayersHouse_1F.warp_1",
            fun m -> warp_to m 6 7 );
          ( "north edge",
            "north Route1",
            fun m ->
              let c = List.hd m.connections in
              Direction.name c.side ^ " " ^ c.connected_map );
        ];
    };
    {
      name = "a Card Key door";
      input = "SilphCo_5F";
      expectation =
        [
          ( "door_1",
            "FLAG_SILPH_5F_DOOR_1 4 tiles, closed",
            fun m ->
              let g = gate_of m "door_1" in
              match g.control with
              | Flag { opener = Card_key; flag } ->
                  Printf.sprintf "%s %d tiles, %s" flag
                    (List.length g.gate_tiles)
                    (if g.open_at_new_game then "open" else "closed")
              | _ -> "not a Card Key door" );
        ];
    };
    {
      name = "the Mansion's statue switch";
      input = "PokemonMansion_1F";
      expectation =
        [
          ( "statue",
            "(5, 5) from (5, 6) north",
            fun m ->
              match (switch_of m "mansion").press with
              | Statues [ s ] ->
                  Printf.sprintf "%s from %s %s"
                    (Tile_pos.to_string s.statue_tile)
                    (Tile_pos.to_string s.face_from)
                    (Direction.name s.facing)
              | _ -> "not one statue" );
          ( "floors",
            "4",
            fun m -> string_of_int (List.length (switch_of m "mansion").floors)
          );
        ];
    };
    {
      name = "a Victory Road button";
      input = "VictoryRoad_1F";
      expectation =
        [
          ( "button",
            "(20, 16) sets 100",
            fun m ->
              match (switch_of m "floor_switch_1").press with
              | Boulder_buttons { buttons = [ b ]; set_value } ->
                  Printf.sprintf "%s sets %d" (Tile_pos.to_string b) set_value
              | _ -> "not one button" );
          ( "barrier top opens to",
            "8",
            fun m ->
              String.make 1
                (Tile_kind.glyph (gate_of m "barrier_1_top").open_tile) );
        ];
    };
  ]

(* Pallet Town's top row carries on as Route 1's bottom row. *)
let walk_north_onto_route_1 () =
  let world = Connected_maps.create [ load "PalletTown"; load "Route1" ] in
  let pallet = Option.get (Connected_maps.find world "PalletTown") in
  match
    Connected_maps.neighbour world
      { map = pallet; tile = { x = 12; y = 0 } }
      North
  with
  | Some { map; tile } ->
      Check.equal "arrival" ~expected:"Route1 (12, 39)"
        ((Connected_maps.map world map).name ^ " " ^ Tile_pos.to_string tile)
  | None -> Error "nowhere"

(* Route 6's hidden items by flag and tile, and the Game Corner's clerk by the
   decompilation's script name. *)
let hidden_items_and_scripts () =
  let route6 = load "Route6" and corner = load "CeladonCity_GameCorner" in
  let hidden =
    List.map
      (fun (h : Map_features.hidden_item) ->
        h.hidden_flag ^ " " ^ Tile_pos.to_string h.hidden_pos)
      route6.hidden_items
  in
  let clerk =
    List.find_map
      (fun (o : Map_features.map_object) ->
        if o.script = Some "CeladonCity_GameCorner_EventScript_CoinsClerk" then
          Some (Tile_pos.to_string o.object_pos)
        else None)
      corner.objects
  in
  Check.equal "hidden items and the coins clerk"
    ~expected:
      "FLAG_HIDDEN_ITEM_ROUTE6_SITRUS_BERRY (5, 5), \
       FLAG_HIDDEN_ITEM_ROUTE6_RARE_CANDY (19, 5); clerk (6, 2)"
    (String.concat ", " hidden ^ "; clerk "
    ^ Option.value ~default:"missing" clerk)

let () =
  Table_test.report "every FRLG runtime map parses" (all_parse maps_dir);
  Table_test.report "every BDSP runtime map parses"
    (all_parse (maps_dir_of "bdsp"));
  List.iter
    (Map_text.run_case ~read_map:(Map_file.load_runtime ~maps_dir))
    cases;
  Table_test.report "north out of Pallet Town onto Route 1"
    (walk_north_onto_route_1 ());
  Table_test.report "hidden items by flag, objects by script"
    (hidden_items_and_scripts ());
  Table_test.finish ()
