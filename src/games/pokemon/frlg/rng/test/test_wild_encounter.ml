(* Slot selection, wild generation and the wild search against the C++'s
   golden vectors (fixtures/wild_encounter.txt). The slot tables come from the
   fixture's "table" lines, which the C++ read from EncounterSlotsFR.json. *)

open Frlg_rng

let records = Fixture_lines.read "fixtures/wild_encounter.txt"

let slot_of_text text : Wild_encounter.slot =
  match String.split_on_char '/' text with
  | [ species; min_level; max_level ] ->
      {
        species;
        min_level = int_of_string min_level;
        max_level = int_of_string max_level;
      }
  | _ -> failwith ("not a slot: " ^ text)

let tables =
  List.filter_map
    (fun (r : Fixture_lines.record) ->
      match (r.op, r.inputs) with
      | "table", [ name ] ->
          let slots = String.split_on_char ' ' r.expected in
          Some (name, Array.of_list (List.map slot_of_text slots))
      | _ -> None)
    records

let table name = List.assoc name tables

let slot = function
  | [ size; super_rod ] ->
      List.init 100 (fun roll ->
          Wild_encounter.slot_number_of_roll ~roll ~size:(int_of_string size)
            ~super_rod:(Search_fixture.flag super_rod))
      |> List.map string_of_int |> String.concat " "
  | _ -> failwith "slot: size super_rod"

let wild = function
  | [ name; seed; advance; m; super_rod ] ->
      let state =
        Rng_state.of_seed ~seed:(Fixture_lines.hex seed)
          ~advance:(int_of_string advance)
          (Search_fixture.rng_method m)
      in
      let w =
        Wild_encounter.pokemon_of_state state (table name)
          ~super_rod:(Search_fixture.flag super_rod)
      in
      Printf.sprintf "%s %s %d %d" w.species
        (Search_fixture.pokemon_text w.pokemon)
        w.slot w.level
  | _ -> failwith "wild: table seed advance method super_rod"

let search_wild = function
  | name :: species :: level :: seeds :: min_advance :: max_advance :: super_rod
    :: filter ->
      let filters, trainer = Search_fixture.filters filter in
      let filters = { filters with species; level = int_of_string level } in
      Target_search.search_wild filters trainer (table name)
        ~super_rod:(Search_fixture.flag super_rod)
        ~seeds:(Search_fixture.seeds seeds)
        ~min_advance:(int_of_string min_advance)
        ~max_advance:(int_of_string max_advance)
      |> Search_fixture.hits_text
  | _ -> failwith "search_wild: table species level seeds min max super filter"

let () =
  let check = Fixture_lines.check_op records in
  check "slot" slot;
  check "wild" wild;
  check "search_wild" search_wild;
  Table_test.finish ()
