(* One-way warps, each kind of gate, and both kinds of switch, parsed from
   a synthetic map. Ported from Pokemon_MapData_Tests.cpp
   (test_one_way_gates_and_switches); the switch with buttons follows
   PokemonSimulation's format (toggle false, set_value, a B tile). *)

open Grid_maps
open Map_fixtures
open Map_text

let cases =
  [
    {
      name = "one-way warps, gates and switches";
      input = gate_map;
      expectation =
        [
          ( "the hole",
            "(2, 2) step_on -> Basement.drop one way",
            fun m -> warp_at m 2 2 );
          ( "card door",
            "card key FLAG_CARD, opens to '.', new game false",
            fun m -> gate m "card_door" );
          ( "quiz door",
            "quiz FLAG_QUIZ, opens to '.', new game false",
            fun m -> gate m "quiz_door" );
          ( "cut tree",
            "cut FLAG_CUT, opens to '.', new game false",
            fun m -> gate m "cut_tree" );
          ( "barrier",
            "switch mansion open when false, opens to '~', new game true",
            fun m -> gate m "barrier" );
          ( "statue switch",
            "FLAG_SWITCH on GateHall,Basement: (0, 0) west",
            fun m -> switch m "mansion" );
          ( "button switch",
            "VAR_FLOOR on GateHall: (2, 1) set 100",
            fun m -> switch m "floor_switch_1" );
          ( "gate count",
            "4",
            fun m -> count (Map_data.String_map.bindings m.gates) );
        ];
    };
  ]

let () =
  List.iter (run_case ~read_map:of_json) cases;
  Case_table.finish ()
