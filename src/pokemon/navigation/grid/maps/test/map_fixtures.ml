(* The synthetic maps the map data tests read and edit, from the C++ fork's
   Pokemon_MapData_Tests.cpp. *)

let valid_map =
  {|{
    "name": "TestTown",
    "source": {"decomp_file": "data/maps/TestTown/map.json", "revision": "abc123", "date": "2026-10-31"},
    "tiles": ["####", "#..~", "#D.S", "w^v#"],
    "points": {"door": [1, 2], "sign": [3, 2]},
    "warps": [{"x": 1, "y": 2, "to_map": "TestHouse", "to_point": "exit"}],
    "objects": [
        {"name": "mom", "kind": "npc", "x": 2, "y": 1, "facing": "south", "wander": {"x0": 1, "y0": 1, "x1": 2, "y1": 2}},
        {"name": "potion", "kind": "item", "x": 2, "y": 2}
    ],
    "connections": [{"side": "east", "to_map": "Route 1", "offset": 0}],
    "patches": [{"x": 2, "y": 1, "glyph": "#", "measured_by": "run 3, 2026-10-30"}]
}|}

(* On a world grid, with tiles off the game's map, a region, a warp tile
   stood on, trainers, a person the story hides and scene triggers. *)
let bdsp_map =
  {|{
    "name": "Route 201",
    "source": {"decomp_file": "pret/pokediamond: land_data narc_0000.bin", "revision": "default branch", "date": "2026-11-01"},
    "world": {"name": "Sinnoh", "x": 96, "y": 839},
    "tiles": ["  ###", " #..#", "#.~..", "#..v#"],
    "points": {"save_spot": [2, 1]},
    "regions": {"lawn": [[3, 2], [1, 2], [1, 3]]},
    "warps": [{"x": 4, "y": 2, "enter": "step_on"}],
    "objects": [
        {"name": "youngster_tristan", "kind": "npc", "x": 3, "y": 1, "facing": "west", "trainer": {"sight": 2}},
        {"name": "lass_natalie", "kind": "npc", "x": 1, "y": 3, "facing": "north", "trainer": {"sight": 3, "looks": ["north", "east"]}},
        {"name": "rowan", "kind": "npc", "x": 2, "y": 3, "hide_flag": "story_after_00.03"}
    ],
    "triggers": [
        {"name": "barry_warning", "box": {"x0": 2, "y0": 1, "x1": 3, "y1": 1}, "when": "00.02"},
        {"name": "border_sign", "box": {"x0": 1, "y0": 2, "x1": 1, "y1": 2}}
    ]
}|}

(* Elevations, one-sided walls, warps of every entry (one to a map not in
   the set), a person hidden by an event flag, and a flag set. *)
let frlg_map =
  {|{
    "name": "CeruleanCave_1F",
    "source": {"decomp_file": "data/maps/CeruleanCave_1F/map.json", "revision": "ce6406d8c2ea", "date": "2026-11-01"},
    "allow_running": false,
    "tiles": ["#..#", "8.2#", "4.6."],
    "elevation": ["3303", "3f03", "0a33"],
    "points": {"warp_0": [1, 0]},
    "warps": [
        {"x": 1, "y": 0, "enter": "cave_entrance", "to_map": "CeruleanCity", "to_point": "warp_6"},
        {"x": 2, "y": 0, "enter": "step_on"},
        {"x": 1, "y": 1, "enter": "walk_north", "to_map": "CeruleanCave_2F", "to_point": "warp_0"},
        {"x": 2, "y": 1, "enter": "walk_south", "to_map": "CeruleanCave_2F", "to_point": "warp_1"},
        {"x": 1, "y": 2, "enter": "walk_west", "to_map": "CeruleanCave_2F", "to_point": "warp_2"},
        {"x": 3, "y": 2, "enter": "walk_east", "to_map": "CeruleanCave_2F", "to_point": "warp_3"}
    ],
    "objects": [
        {"name": "cooltrainer_m_1", "kind": "npc", "x": 1, "y": 1, "hide_flag": "FLAG_HIDE_CERULEAN_CAVE_GUARD",
         "wander": {"x0": 1, "y0": 1, "x1": 2, "y1": 1}}
    ],
    "flag_sets": {"after_hall_of_fame": ["FLAG_B", "FLAG_HIDE_CERULEAN_CAVE_GUARD", "FLAG_B"]}
}|}

let required_only =
  {|{"name": "Cave", "source": {"decomp_file": "f", "revision": "r", "date": "d"}, "tiles": ["#.#"]}|}

let spin_room =
  {|{"name": "SpinRoom", "source": {"decomp_file": "f", "revision": "r", "date": "d"}, "tiles": ["udlroHBiI"]}|}

(* Each gate kind, and both kinds of switch. *)
let gate_map =
  {|{
    "name": "GateHall",
    "source": {"decomp_file": "f", "revision": "r", "date": "d"},
    "tiles": ["#G.G#", "#GBG#", "#.H.#"],
    "warps": [{"x": 2, "y": 2, "enter": "step_on", "one_way": true, "to_map": "Basement", "to_point": "drop"}],
    "gates": {
        "card_door": {"tiles": [[1, 0]], "open_glyph": ".", "new_game": "closed", "opens_by": "card_key_face_a", "flag": "FLAG_CARD"},
        "quiz_door": {"tiles": [[3, 0]], "open_glyph": ".", "new_game": "closed", "opens_by": "quiz_answer", "flag": "FLAG_QUIZ"},
        "cut_tree": {"tiles": [[1, 1]], "open_glyph": ".", "new_game": "closed", "opens_by": "cut", "flag": "FLAG_CUT"},
        "barrier": {"tiles": [[3, 1]], "open_glyph": "~", "new_game": "open", "switch": "mansion", "open_when": "off"}
    },
    "switches": {
        "mansion": {"flag": "FLAG_SWITCH", "toggle": true, "floors": ["GateHall", "Basement"],
                    "statues": [{"coord": [0, 0], "face_from": [1, 0], "facing": "west"}]},
        "floor_switch_1": {"flag": "VAR_FLOOR", "toggle": false, "floors": ["GateHall"], "set_value": 100,
                           "pressed_by": "strength_boulder", "buttons": [{"coord": [2, 1]}]}
    }
}|}
