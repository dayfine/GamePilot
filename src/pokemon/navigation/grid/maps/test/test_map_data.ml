(* Map_file.parse on small synthetic maps: the C++ fork's valid map, a map
   with only the required fields, glyphs, and maps shaped like each game's
   (BDSP, FRLG); tiles_to_door along a corridor. Ported from
   Pokemon_MapData_Tests.cpp. *)

open Grid_maps
open Grid_geometry
open Map_features
open Map_fixtures
open Map_text

let valid_map_case =
  {
    name = "the valid map";
    input = valid_map;
    expectation =
      [
        ( "name and source",
          "TestTown data/maps/TestTown/map.json abc123 2026-10-31",
          fun m ->
            String.concat " "
              [ m.name; m.source.decomp_file; m.source.revision; m.source.date ]
        );
        ( "size",
          "4x4",
          fun m ->
            Printf.sprintf "%dx%d" (Grid.width m.tiles) (Grid.height m.tiles) );
        ( "row 1..3 glyphs",
          "~DSw^v",
          fun m ->
            String.concat ""
              [
                glyph_at m 3 1;
                glyph_at m 1 2;
                glyph_at m 3 2;
                glyph_at m 0 3;
                glyph_at m 1 3;
                glyph_at m 2 3;
              ] );
        ( "the patch made (2, 1) a wall",
          "# run 3, 2026-10-30",
          fun m -> glyph_at m 2 1 ^ " " ^ (List.hd m.patches).measured_by );
        ( "points",
          "(1, 2) (3, 2)",
          fun m -> point m "door" ^ " " ^ point m "sign" );
        ( "the warp",
          "(1, 2) walk_into -> TestHouse.exit",
          fun m -> warp_at m 1 2 );
        ( "mom",
          "mom south (1, 1)(2, 2)",
          fun m ->
            object_field m 0 (fun o ->
                Printf.sprintf "%s %s %s" o.object_name
                  (opt (Option.map Direction.name o.facing))
                  (opt (Option.map box o.wander))) );
        ( "the potion",
          "item (none) (none)",
          fun m ->
            object_field m 1 (fun o ->
                Printf.sprintf "%s %s %s"
                  (if o.kind = Item then "item" else "?")
                  (opt (Option.map Direction.name o.facing))
                  (opt (Option.map box o.wander))) );
        ( "connection",
          "east Route 1 0",
          fun m ->
            let c = List.hd m.connections in
            Printf.sprintf "%s %s %d" (Direction.name c.side) c.connected_map
              c.shift );
      ];
  }

let required_only_case =
  {
    name = "lists may be left out";
    input = required_only;
    expectation =
      [
        ( "size",
          "3x1",
          fun m ->
            Printf.sprintf "%dx%d" (Grid.width m.tiles) (Grid.height m.tiles) );
        ( "running, no world or elevation",
          "true false false",
          fun m ->
            Printf.sprintf "%b %b %b" m.allow_running (Option.is_some m.world)
              (Option.is_some m.elevation) );
        ( "nothing on it",
          "0 0 0 0 0 0 0 0 0 0",
          fun m ->
            String.concat " "
              (List.map string_of_int
                 [
                   Map_data.String_map.cardinal m.points;
                   Map_data.String_map.cardinal m.regions;
                   List.length m.warps;
                   List.length m.objects;
                   List.length m.triggers;
                   Map_data.String_map.cardinal m.flag_sets;
                   List.length m.connections;
                   List.length m.patches;
                   Map_data.String_map.cardinal m.gates;
                   Map_data.String_map.cardinal m.switches;
                 ]) );
      ];
  }

let glyph_rows_case =
  {
    name = "spin, hole, button and ice glyphs";
    input = spin_room;
    expectation =
      [
        ( "row 0",
          "udlroHBiI",
          fun m -> String.concat "" (List.init 9 (fun x -> glyph_at m x 0)) );
      ];
  }

let bdsp_case =
  {
    name = "a map shaped like BDSP's";
    input = bdsp_map;
    expectation =
      [
        ( "world",
          "Sinnoh (96, 839)",
          fun m ->
            match m.world with
            | Some w -> w.world_name ^ " " ^ Tile_pos.to_string w.offset
            | None -> "(none)" );
        ("tiles off the map", "  ", fun m -> glyph_at m 0 0 ^ glyph_at m 0 1);
        ( "region lawn, in order",
          "(3, 2)(1, 2)(1, 3)",
          fun m -> tiles (Map_data.String_map.find "lawn" m.regions) );
        ( "warp_at (4, 2)",
          "(4, 2) step_on -> (not in the set)",
          fun m -> warp_at m 4 2 );
        ("warp_at (3, 2)", "(none)", fun m -> warp_at m 3 2);
        ( "Tristan, sight along his facing",
          "sight 2, looks west",
          fun m -> trainer m 0 );
        ( "Natalie, sight both ways",
          "sight 3, looks north east",
          fun m -> trainer m 1 );
        ("Rowan is no trainer", "(none)", fun m -> trainer m 2);
        ( "hide flags",
          "story_after_00.03 (none)",
          fun m ->
            object_field m 2 (fun o -> opt o.hide_flag)
            ^ " "
            ^ object_field m 0 (fun o -> opt o.hide_flag) );
        ( "trigger 0",
          "barry_warning (2, 1)(3, 1) 00.02",
          fun m ->
            let t = List.hd m.triggers in
            Printf.sprintf "%s %s %s" t.trigger_name (box t.box)
              (opt t.story_when) );
        ( "trigger 1, any time",
          "border_sign (none)",
          fun m ->
            let t = List.nth m.triggers 1 in
            t.trigger_name ^ " " ^ opt t.story_when );
      ];
  }

let frlg_case =
  {
    name = "a map shaped like FRLG's";
    input = frlg_map;
    expectation =
      [
        ( "closed sides",
          "8246",
          fun m ->
            glyph_at m 0 1 ^ glyph_at m 2 1 ^ glyph_at m 0 2 ^ glyph_at m 2 2 );
        ( "elevations",
          "0 15 10",
          fun m ->
            String.concat " "
              [ elevation_at m 2 0; elevation_at m 1 1; elevation_at m 1 2 ] );
        ( "cave entrance",
          "(1, 0) cave_entrance -> CeruleanCity.warp_6",
          fun m -> warp_at m 1 0 );
        ( "ladder to a map not in the set",
          "(2, 0) step_on -> (not in the set)",
          fun m -> warp_at m 2 0 );
        ( "mat north",
          "(1, 1) walk_north -> CeruleanCave_2F.warp_0",
          fun m -> warp_at m 1 1 );
        ( "mat south",
          "(2, 1) walk_south -> CeruleanCave_2F.warp_1",
          fun m -> warp_at m 2 1 );
        ( "mat west",
          "(1, 2) walk_west -> CeruleanCave_2F.warp_2",
          fun m -> warp_at m 1 2 );
        ( "mat east",
          "(3, 2) walk_east -> CeruleanCave_2F.warp_3",
          fun m -> warp_at m 3 2 );
        ( "the guard's hide flag",
          "FLAG_HIDE_CERULEAN_CAVE_GUARD",
          fun m -> object_field m 0 (fun o -> opt o.hide_flag) );
        ( "flag set, each flag once",
          "FLAG_B FLAG_HIDE_CERULEAN_CAVE_GUARD",
          fun m -> flag_set m "after_hall_of_fame" );
        ("no running", "false", fun m -> string_of_bool m.allow_running);
      ];
  }

let cases =
  [ valid_map_case; required_only_case; glyph_rows_case; bdsp_case; frlg_case ]

let glyphs_round_trip () =
  let wrong =
    List.filter
      (fun glyph ->
        Option.map Tile_kind.glyph (Tile_kind.of_glyph glyph) <> Some glyph)
      (List.of_seq (String.to_seq "#.~wv^<>DS 8246udlroHBiIG"))
  in
  match (wrong, Tile_kind.of_glyph '?') with
  | [], None -> Ok ()
  | [], Some _ -> Error "'?' is not a glyph"
  | glyph :: _, _ ->
      Error (Printf.sprintf "glyph '%c' does not round-trip" glyph)

(* A 3x22 corridor of walls with a door at (1, 0) and open (1, 1..20). *)
let corridor =
  Grid.init ~width:3 ~height:22 (fun { x; y } ->
      match (x, y) with
      | 1, 0 -> Tile_kind.Door
      | 1, y when y <= 20 -> Open
      | _ -> Wall)

type door_case = {
  door_name : string;
  from : Tile_pos.t * Direction.t;
  tiles : int;  (** Tiles walked, up to and including the door or wall. *)
}

let door_cases =
  [
    {
      door_name = "twenty tiles north to the door";
      from = ({ x = 1; y = 20 }, North);
      tiles = 20;
    };
    { door_name = "the doorstep"; from = ({ x = 1; y = 1 }, North); tiles = 1 };
    {
      door_name = "south to the wall row";
      from = ({ x = 1; y = 1 }, South);
      tiles = 20;
    };
    {
      door_name = "a wall next to the tile";
      from = ({ x = 1; y = 1 }, East);
      tiles = 1;
    };
  ]

let run_door_case { door_name; from = pos, direction; tiles } =
  Table_test.report
    ("tiles_to_door: " ^ door_name)
    (Check.equal "tiles" ~expected:(string_of_int tiles)
       (string_of_int (Map_data.tiles_to_door corridor pos direction)))

let () =
  List.iter (run_case ~read_map:of_json) cases;
  Table_test.report "glyphs round-trip" (glyphs_round_trip ());
  List.iter run_door_case door_cases;
  Table_test.finish ()
