(* Static generation and the starter's search against the C++'s golden vectors
   (fixtures/bdsp_rng.txt). *)

open Bdsp_rng
open Static_encounter

let records = Fixture_lines.read "fixtures/bdsp_rng.txt"
let hex = Fixture_lines.hex
let hex32 = Fixture_lines.hex32
let no_synchronize = 255

(* The C++'s enum values, as the generator prints them. *)
let shiny_value = function Not_shiny -> 0 | Star -> 1 | Square -> 2
let gender_value = function Male -> 0 | Female -> 1 | Genderless -> 2

(* The templates generate_golden.cpp names. *)
let template = function
  | "starter" ->
      { species = "starter"; level = 5; guaranteed_ivs = 0; ability_kind = 3;
        gender_ratio = 31; shiny_locked = false }
  | "legendary" ->
      { species = "legendary"; level = 50; guaranteed_ivs = 3; ability_kind = 3;
        gender_ratio = 255; shiny_locked = false }
  | "locked_hidden_female" ->
      { species = "locked_hidden_female"; level = 1; guaranteed_ivs = 1;
        ability_kind = 2; gender_ratio = 254; shiny_locked = true }
  | name -> failwith ("unknown template " ^ name)
[@@ocamlformat "disable"]

let state_of = function
  | s0 :: s1 :: s2 :: s3 :: rest ->
      ({ Xorshift128.s0 = hex s0; s1 = hex s1; s2 = hex s2; s3 = hex s3 }, rest)
  | inputs -> failwith ("not a state: " ^ String.concat " " inputs)

let state_text (s : Xorshift128.state) =
  String.concat " " (List.map hex32 [ s.s0; s.s1; s.s2; s.s3 ])

let pokemon_text p =
  Printf.sprintf "%s %s %d %s %d %d %d %d %d %d" (hex32 p.ec) (hex32 p.pid)
    (shiny_value p.shiny) (ivs_to_string p.ivs) p.ability
    (gender_value p.gender) p.nature p.level p.height p.weight

let synchronize text =
  match int_of_string text with
  | n when n = no_synchronize -> None
  | n -> Some n

let shiny = function
  | [ pid; tsv ] ->
      let pid = hex pid and tsv = int_of_string tsv in
      Printf.sprintf "%d %d"
        (shiny_value (shiny_of_pid ~pid ~tsv))
        (Bool.to_int (is_shiny ~pid ~tsv))
  | _ -> failwith "shiny: pid tsv"

let nature inputs = nature_name (int_of_string (List.hd inputs))

let generate_line inputs =
  match state_of inputs with
  | state, [ name; tsv; sync ] ->
      generate state (template name) ~tsv:(int_of_string tsv)
        ~synchronize_nature:(synchronize sync)
      |> pokemon_text
  | _ -> failwith "generate: state template tsv synchronize"

let searcher_of state name tsv =
  searcher state (template name) ~tsv:(int_of_string tsv)
    ~synchronize_nature:None

let searcher_generate inputs =
  match state_of inputs with
  | state, [ name; tsv; advances ] ->
      pokemon_text
        (generate_at (searcher_of state name tsv) (int_of_string advances))
  | _ -> failwith "searcher_generate: state template tsv advances"

let hit_line h =
  Printf.sprintf "  hit %d %s %s" h.advances (state_text h.state)
    (pokemon_text h.pokemon)

let scan_line accept inputs =
  match state_of inputs with
  | state, [ name; tsv; low; high ] ->
      let hits =
        scan
          (searcher_of state name tsv)
          ~min_advances:(int_of_string low) ~max_advances:(int_of_string high)
          ~accept
      in
      String.concat "\n"
        (string_of_int (List.length hits) :: List.map hit_line hits)
  | _ -> failwith "scan: state template tsv min max"

let adamant = 3
let unshiny_bit = 0x1000_0000
let max_iv = 31

let () =
  let check = Fixture_lines.check_op records in
  check "shiny" shiny;
  check "nature" nature;
  check "generate" generate_line;
  check "searcher_generate" searcher_generate;
  check "scan_shiny" (scan_line (fun p -> p.shiny <> Not_shiny));
  check "scan_unshinied"
    (scan_line (fun p -> is_shiny ~pid:(p.pid lxor unshiny_bit) ~tsv:0));
  check "scan_adamant_31atk"
    (scan_line (fun p -> p.nature = adamant && p.ivs.attack = max_iv));
  Table_test.finish ()
