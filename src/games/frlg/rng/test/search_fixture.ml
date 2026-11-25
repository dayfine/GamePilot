(* The generator's text for methods, filters, results and hits. *)

open Frlg_rng

let rng_method = function
  | "m1" -> Rng_state.Method1
  | "m2" -> Method2
  | "m3" -> Method3
  | "m4" -> Method4
  | "any" -> Any
  | text -> failwith ("not a method: " ^ text)

let method_text = function
  | Rng_state.Method1 -> "m1"
  | Method2 -> "m2"
  | Method3 -> "m3"
  | Method4 -> "m4"
  | Any -> "any"

let flag text = text = "1"
let seeds text = List.map Fixture_lines.hex (String.split_on_char ',' text)

(* An enum number, [None] for the last value (the C++'s Any). *)
let enum values text =
  let n = int_of_string text in
  if n = List.length values then None else Some (List.nth values n)

let range text =
  match String.split_on_char '-' text with
  | [ low; high ] ->
      { Target_search.low = int_of_string low; high = int_of_string high }
  | _ -> failwith ("not an IV range: " ^ text)

let filters = function
  | [ m; nature; ability; gender; shiny; hp; atk; def; spa; spd; spe; gt; tsv ]
    ->
      ( {
          Target_search.species = "";
          level = 0;
          gender = enum [ Pokemon_generation.Male; Female ] gender;
          nature = enum (List.init 25 Fun.id) nature;
          ability = enum [ 0; 1 ] ability;
          ivs =
            {
              hp = range hp;
              attack = range atk;
              defense = range def;
              spatk = range spa;
              spdef = range spd;
              speed = range spe;
            };
          shiny = enum [ Pokemon_generation.Normal; Star; Square ] shiny;
          rng_method = rng_method m;
        },
        {
          Target_search.gender_threshold = int_of_string gt;
          tid_xor_sid = Fixture_lines.hex tsv;
        } )
  | inputs -> failwith ("not a filter: " ^ String.concat " " inputs)

let pokemon_text (p : Pokemon_generation.result) =
  let { Pokemon_generation.hp; attack; defense; spatk; spdef; speed } = p.ivs in
  Printf.sprintf "%08x %d %d %d %d %d %d %d %d %d" p.pid p.gender_value p.nature
    p.ability hp attack defense spatk spdef speed

let hits_text hits =
  List.map
    (fun (h : Rng_state.t) ->
      Printf.sprintf "%04x:%d:%s" h.seed h.advance (method_text h.rng_method))
    hits
  |> List.cons (string_of_int (List.length hits))
  |> String.concat " "
