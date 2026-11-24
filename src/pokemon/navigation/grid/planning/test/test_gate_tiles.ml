(* What the gate state makes of the tiles, and which switch a button or a
   statue belongs to. Ported from the C++ fork's Pokemon_Gates_Tests.cpp; its
   reader cases (card-key doors, switches, gate errors) and the gate change
   case are the map model's tests (grid/maps/test). *)

open Grid_maps
open Grid_planning
module Names = Gate_state.Names

let pos x y = { Tile_pos.x; y }

let synthetic name tiles gates switches =
  Gate_maps.of_json name
    (Printf.sprintf
       {|{"format": "pokesim-runtime-map/2", "name": "%s",
          "source": {"decomp_file": "x", "revision": "y", "date": "z"},
          "tiles": [%s], "gates": {%s}, "switches": {%s}}|}
       name tiles gates switches)

let quiz_map =
  synthetic "T" {|"...", "GG.", "..."|}
    {|"door_1": {"tiles": [[0, 1], [1, 1]], "open_glyph": ".", "new_game": "closed",
                 "opens_by": "quiz_answer", "flag": "FLAG_CINNABAR_GYM_QUIZ_1"}|}
    ""

let cut_map =
  synthetic "T" {|"...", ".G.", "..."|}
    {|"cut_tree_1_1": {"tiles": [[1, 1]], "open_glyph": "~", "new_game": "closed",
                       "opens_by": "cut", "flag": "FLAG_TEMP_13"}|}
    ""

let button_map =
  synthetic "VictoryRoad_1F" {|"G..", "...", ".B."|}
    {|"barrier_1": {"tiles": [[0, 0]], "open_glyph": ".", "new_game": "closed",
                    "switch": "floor_switch_1", "open_when": "on"}|}
    {|"floor_switch_1": {"flag": "FLAG_VR_1F", "toggle": false, "set_value": 100,
                         "floors": ["VictoryRoad_1F"], "buttons": [{"coord": [1, 2]}]}|}

let opened key = { Gate_state.new_game with opened = Names.singleton key }
let switch_on id = { Gate_state.new_game with switches_on = Names.singleton id }

let glyph map state tile =
  String.make 1 (Tile_kind.glyph (Gate_tiles.resolved_tile map state tile))

let face map state from direction =
  match Gate_tiles.closed_card_key_gate_faced map state from direction with
  | Some gate -> gate.gate_id
  | None -> "none"

let button map tile =
  match Gate_tiles.switch_with_button map tile with
  | Some pressed -> Gate_tiles.switch_key pressed
  | None -> "none"

let silph = Connected_maps.map Gate_maps.world Gate_maps.silph
let first = Connected_maps.map Gate_maps.world Gate_maps.mansion_1f
let third = Connected_maps.map Gate_maps.world Gate_maps.mansion_3f
let silph_door = opened (Gate_state.gate_key ~map:"SilphCo_5F" ~gate:"door_1")

let one_way (map : Map_data.t) =
  List.length (List.filter (fun (w : Map_features.warp) -> w.one_way) map.warps)

type case = { name : string; input : unit -> string; expectation : string }

let cases =
  let none = Gate_state.new_game in
  [
    {
      name = "a shut quiz door is a wall";
      input = (fun () -> glyph quiz_map none (pos 0 1));
      expectation = "#";
    };
    {
      name = "a quiz door is not opened by facing it";
      input = (fun () -> face quiz_map none (pos 0 0) South);
      expectation = "none";
    };
    {
      name = "an opened quiz door is floor";
      input = (fun () -> glyph quiz_map (opened "T/door_1") (pos 1 1));
      expectation = ".";
    };
    {
      name = "a standing tree is a wall";
      input = (fun () -> glyph cut_map none (pos 1 1));
      expectation = "#";
    };
    {
      name = "a tree is not cut by facing it";
      input = (fun () -> face cut_map none (pos 1 0) South);
      expectation = "none";
    };
    {
      name = "a cut tree's tile is its ground";
      input = (fun () -> glyph cut_map (opened "T/cut_tree_1_1") (pos 1 1));
      expectation = "~";
    };
    {
      name = "a one-floor switch is keyed by map and id";
      input = (fun () -> button button_map (pos 1 2));
      expectation = "VictoryRoad_1F/floor_switch_1";
    };
    {
      name = "no switch button where none is";
      input = (fun () -> button button_map (pos 0 0));
      expectation = "none";
    };
    {
      name = "a closed Card Key door is a wall";
      input = (fun () -> glyph silph none (pos 7 9));
      expectation = "#";
    };
    {
      name = "a closed Card Key door is faced";
      input = (fun () -> face silph none (pos 9 9) West);
      expectation = "door_1";
    };
    {
      name = "an opened door is floor";
      input = (fun () -> glyph silph silph_door (pos 7 9));
      expectation = ".";
    };
    {
      name = "only the opened door opens";
      input = (fun () -> glyph silph silph_door (pos 7 18));
      expectation = "#";
    };
    {
      name = "resolve_tiles agrees";
      input =
        (fun () ->
          String.make 1
            (Tile_kind.glyph
               (Grid.get (Gate_tiles.resolve_tiles silph silph_door) (pos 8 10))));
      expectation = ".";
    };
    {
      name = "1F barrier_1 shut with the switch off";
      input = (fun () -> glyph first none (pos 22 10));
      expectation = "#";
    };
    {
      name = "1F barrier_1 open with the switch on";
      input = (fun () -> glyph first (switch_on "mansion") (pos 22 10));
      expectation = "~";
    };
    {
      name = "3F barrier_1 open with the switch off";
      input = (fun () -> glyph third none (pos 21 6));
      expectation = "~";
    };
    {
      name = "3F barrier_1 shut with the switch on";
      input = (fun () -> glyph third (switch_on "mansion") (pos 21 6));
      expectation = "#";
    };
    {
      name = "3F's holes are one-way warps";
      input = (fun () -> string_of_int (one_way third));
      expectation = "5";
    };
    {
      name = "1F has no one-way warp";
      input = (fun () -> string_of_int (one_way first));
      expectation = "0";
    };
  ]

let () =
  List.iter
    (fun { name; input; expectation } ->
      Table_test.report name (Check.equal ~expected:expectation (input ())))
    cases;
  Table_test.finish ()
