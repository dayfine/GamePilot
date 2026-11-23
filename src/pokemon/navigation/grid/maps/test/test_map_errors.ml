(* Map_file.parse rejects one broken thing per row, naming the file, the
   field and what is wrong. Ported from Pokemon_MapData_Tests.cpp
   (test_each_error_class, _of_game_fields, test_gate_and_switch_errors). *)

open Grid_maps
open Map_fixtures

type case = {
  name : string;
  input : string;  (** The map file's JSON. *)
  expectation : string list;  (** What the error must name. *)
}

let row name (base, find, replacement) expectation =
  { name; input = Check.edited base find replacement; expectation }

let v = valid_map
and b = bdsp_map
and f = frlg_map
and g = gate_map

let valid_map_rows =
  [
    {
      name = "not an object";
      input = "[]";
      expectation = [ "Test.json"; "not a JSON object" ];
    };
    row "missing name"
      (v, {|"name": "TestTown"|}, {|"title": "TestTown"|})
      [ "Test.json"; "name is missing" ];
    row "name not a string"
      (v, {|"name": "TestTown"|}, {|"name": 7|})
      [ "name is not a string" ];
    row "source missing a field"
      (v, {|"revision": "abc123"|}, {|"rev": "abc123"|})
      [ "source.revision is missing" ];
    row "tiles without rows"
      (v, {|"tiles": ["####", "#..~", "#D.S", "w^v#"]|}, {|"tiles": []|})
      [ "tiles has no rows" ];
    row "ragged row"
      (v, {|"#..~"|}, {|"#..~."|})
      [ "tiles[1]"; "string of 4 glyphs" ];
    row "unknown glyph"
      (v, {|"#..~"|}, {|"#.?~"|})
      [ "tiles[1]"; "unknown glyph '?'"; "(2, 1)" ];
    row "point not a pair"
      (v, {|"door": [1, 2]|}, {|"door": [1]|})
      [ "points.door"; "[x, y]" ];
    row "point outside"
      (v, {|"sign": [3, 2]|}, {|"sign": [4, 2]|})
      [ "points.sign"; "(4, 2)"; "outside the 4x4 map" ];
    row "warp missing to_point"
      (v, {|"to_point": "exit"|}, {|"to": "exit"|})
      [ "warps[0].to_point is missing" ];
    row "warp missing to_map"
      (v, {|"to_map": "TestHouse"|}, {|"map": "TestHouse"|})
      [ "warps[0].to_map is missing" ];
    row "warp entry unknown"
      (v, {|"to_map": "TestHouse"|}, {|"enter": "jump", "to_map": "TestHouse"|})
      [ "warps[0].enter"; "jump"; "walk_into" ];
    row "warp field of the wrong type"
      (v, {|{"x": 1, "y": 2, "to_map"|}, {|{"x": "1", "y": 2, "to_map"|})
      [ "warps[0].x is not an integer" ];
    row "object kind unknown"
      (v, {|"kind": "item"|}, {|"kind": "boss"|})
      [ "objects[1].kind"; "boss"; "npc, item or sign" ];
    row "object facing unknown"
      (v, {|"facing": "south"|}, {|"facing": "down"|})
      [ "objects[0].facing"; "down"; "north, east, south or west" ];
    row "wander not a box"
      (v, {|"x1": 2, "y1": 2|}, {|"x1": 0, "y1": 2|})
      [ "objects[0].wander is not a box" ];
    row "wander outside"
      (v, {|"x1": 2, "y1": 2|}, {|"x1": 2, "y1": 7|})
      [ "objects[0].wander"; "(2, 7)"; "outside" ];
    row "connection side unknown"
      (v, {|"side": "east"|}, {|"side": "up"|})
      [ "connections[0].side"; "up" ];
    row "patch glyph unknown"
      (v, {|"glyph": "#"|}, {|"glyph": "?"|})
      [ "patches[0].glyph"; "?"; "not a tile glyph" ];
    row "patch outside"
      (v, {|{"x": 2, "y": 1, "glyph"|}, {|{"x": 2, "y": 9, "glyph"|})
      [ "patches[0]"; "(2, 9)"; "outside" ];
  ]

let game_field_rows =
  [
    row "world missing a field"
      (b, {|"name": "Sinnoh"|}, {|"grid": "Sinnoh"|})
      [ "world.name is missing" ];
    row "unknown glyph"
      (b, {|"  ###"|}, {|"  #9#"|})
      [ "tiles[0]"; "unknown glyph '9'" ];
    row "region empty"
      (b, "[[3, 2], [1, 2], [1, 3]]", "[]")
      [ "regions.lawn"; "non-empty" ];
    row "region tile not a pair"
      (b, "[[3, 2], [1, 2]", "[[3, 2], [1]")
      [ "regions.lawn[1]"; "[x, y]" ];
    row "region tile outside"
      (b, "[[3, 2], [1, 2]", "[[3, 2], [9, 2]")
      [ "regions.lawn[1]"; "(9, 2)"; "outside" ];
    row "trainer with no way to look"
      (b, {|"facing": "west", |}, "")
      [ "objects[0].trainer.looks is missing" ];
    row "trainer sight below 1"
      (b, {|"sight": 2|}, {|"sight": 0|})
      [ "objects[0].trainer.sight 0"; "at least 1" ];
    row "trainer looks unknown"
      (b, {|["north", "east"]|}, {|["north", "up"]|})
      [ "objects[1].trainer.looks[1]"; "up" ];
    row "hide flag not a string"
      (b, {|"story_after_00.03"|}, "3")
      [ "objects[2].hide_flag is not a string" ];
    row "trigger missing its box"
      (b, {|"box": {"x0": 2|}, {|"area": {"x0": 2|})
      [ "triggers[0].box is missing" ];
    row "trigger outside"
      (b, {|"x1": 3, "y1": 1|}, {|"x1": 7, "y1": 1|})
      [ "triggers[0].box"; "(7, 1)"; "outside" ];
    row "warp entry unknown"
      (f, {|"step_on"|}, {|"fly"|})
      [ "warps[1].enter"; "fly" ];
    row "elevation rows missing" (f, {|, "0a33"]|}, "]")
      [ "elevation has 2 rows"; "tiles' 3" ];
    row "elevation row short" (f, {|"3f03"|}, {|"3f0"|})
      [ "elevation[1]"; "4 hex digits" ];
    row "elevation not hex"
      (f, {|"3f03"|}, {|"3g03"|})
      [ "elevation[1]"; "'g'"; "not a hex digit" ];
    row "elevation in upper case"
      (f, {|"3f03"|}, {|"3F03"|})
      [ "elevation[1]"; "'F'"; "not a hex digit" ];
    row "flag set not a list"
      ( f,
        {|["FLAG_B", "FLAG_HIDE_CERULEAN_CAVE_GUARD", "FLAG_B"]|},
        {|"FLAG_B"|} )
      [ "flag_sets.after_hall_of_fame"; "not a list" ];
    row "flag not a string"
      (f, {|["FLAG_B", |}, "[7, ")
      [ "flag_sets.after_hall_of_fame[0] is not a string" ];
    row "allow_running not a boolean"
      (f, {|"allow_running": false|}, {|"allow_running": 0|})
      [ "allow_running is not true or false" ];
  ]

let gate_rows =
  [
    row "gate tile in two gates"
      (g, {|"tiles": [[3, 1]]|}, {|"tiles": [[1, 0]]|})
      [ "another gate" ];
    row "gate tile not G"
      (g, {|"tiles": [[1, 0]]|}, {|"tiles": [[2, 0]]|})
      [ "not a G tile" ];
    row "G tile in no gate" (g, {|"#.H.#"|}, {|"#GH.#"|}) [ "no gate lists" ];
    row "unknown switch"
      (g, {|"switch": "mansion"|}, {|"switch": "other"|})
      [ "not in switches" ];
    row "open_glyph G"
      (g, {|"open_glyph": "~"|}, {|"open_glyph": "G"|})
      [ "open_glyph" ];
    row "open_glyph not in the format's set"
      (g, {|"open_glyph": "~"|}, {|"open_glyph": "D"|})
      [ "open_glyph"; "\"D\"" ];
    row "unknown opens_by"
      (g, {|"opens_by": "cut"|}, {|"opens_by": "surf"|})
      [ "opens_by"; "surf" ];
    row "both key and switch"
      (g, {|"flag": "FLAG_CARD"|}, {|"flag": "FLAG_CARD", "switch": "mansion"|})
      [ "not both" ];
    row "flag gate open at a new game"
      ( g,
        {|"new_game": "closed", "opens_by": "cut"|},
        {|"new_game": "open", "opens_by": "cut"|} )
      [ "gates.cut_tree.new_game is open" ];
    row "switch gate starts as the switch is off"
      (g, {|"new_game": "open", "switch"|}, {|"new_game": "closed", "switch"|})
      [ "gates.barrier.new_game is closed" ];
    row "switch floors miss this map"
      (g, {|"floors": ["GateHall", "Basement"]|}, {|"floors": ["Basement"]|})
      [ "switches.mansion.floors"; "GateHall" ];
    row "statue faced from elsewhere"
      (g, {|"facing": "west"|}, {|"facing": "north"|})
      [ "switches.mansion.statues[0]"; "does not face" ];
    row "button not on a B tile"
      (g, {|"buttons": [{"coord": [2, 1]}]|}, {|"buttons": [{"coord": [2, 0]}]|})
      [ "switches.floor_switch_1.buttons[0]"; "Strength button" ];
    row "button switch without set_value"
      (g, {|"set_value": 100,|}, "")
      [ "switches.floor_switch_1.set_value is missing" ];
    row "hole warp not one way"
      (g, {|"one_way": true, |}, "")
      [ "warps[0]"; "hole" ];
  ]

let run_case { name; input; expectation } =
  Case_table.report name
    (match Map_file.of_string ~source_name:"Test.json" input with
    | Ok _ -> Error "parsed"
    | Error message -> Check.mentions message expectation)

let () =
  List.iter run_case (valid_map_rows @ game_field_rows @ gate_rows);
  Case_table.finish ()
