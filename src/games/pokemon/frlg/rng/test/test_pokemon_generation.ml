(* Method 1/2/4 generation, shininess and the static search against the C++'s
   golden vectors (fixtures/pokemon_generation.txt). *)

open Frlg_rng

let records = Fixture_lines.read "fixtures/pokemon_generation.txt"

let pokemon = function
  | [ seed; advance; m; roaming ] ->
      Rng_state.of_seed ~seed:(Fixture_lines.hex seed)
        ~advance:(int_of_string advance)
        (Search_fixture.rng_method m)
      |> Pokemon_generation.pokemon_of_state
           ~roaming:(Search_fixture.flag roaming)
      |> Search_fixture.pokemon_text
  | _ -> failwith "pokemon: seed advance method roaming"

let shiny = function
  | [ pid; tsv ] -> (
      match
        Pokemon_generation.shiny_type_of_pid (Fixture_lines.hex pid)
          ~tid_xor_sid:(Fixture_lines.hex tsv)
      with
      | Normal -> "0"
      | Star -> "1"
      | Square -> "2")
  | _ -> failwith "shiny: pid tsv"

let search_static = function
  | seeds :: min_advance :: max_advance :: roaming :: filter ->
      let filters, trainer = Search_fixture.filters filter in
      Target_search.search_static
        ~roaming:(Search_fixture.flag roaming)
        filters trainer
        ~seeds:(Search_fixture.seeds seeds)
        ~min_advance:(int_of_string min_advance)
        ~max_advance:(int_of_string max_advance)
      |> Search_fixture.hits_text
  | _ -> failwith "search_static: seeds min max roaming filter"

let () =
  let check = Fixture_lines.check_op records in
  check "pokemon" pokemon;
  check "shiny" shiny;
  check "search_static" search_static;
  Table_test.finish ()
