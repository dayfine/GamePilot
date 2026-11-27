(* Static encounter table invariants, PokeFinder 4.x / C++ golden vectors for
   Kyogre, Groudon, and HA Ramanas targets, and Synchronize-aware hit
   identification at legendary levels. *)

open Bdsp_rng

let hex32 = Fixture_lines.hex32

let shiny_value = function
  | Static_encounter.Not_shiny -> 0
  | Star -> 1
  | Square -> 2

let gender_value = function
  | Static_encounter.Male -> 0
  | Female -> 1
  | Genderless -> 2

let pokemon_text (p : Static_encounter.pokemon) =
  Printf.sprintf "%s %s %d %s %d %d %d %d %d %d" (hex32 p.ec) (hex32 p.pid)
    (shiny_value p.shiny)
    (Static_encounter.ivs_to_string p.ivs)
    p.ability (gender_value p.gender) p.nature p.level p.height p.weight

let check_pokemon name ~(expected : Static_encounter.pokemon)
    ~(actual : Static_encounter.pokemon) =
  Table_test.report name
    (if expected = actual then Ok ()
     else
       Error
         (Printf.sprintf "expected %S, got %S" (pokemon_text expected)
            (pokemon_text actual)))

let ivs hp attack defense spatk spdef speed : Static_encounter.ivs =
  { hp; attack; defense; spatk; spdef; speed }

let mk_pokemon ~ec ~pid ~shiny ~ivs ~ability ~nature ~height ~weight :
    Static_encounter.pokemon =
  {
    ec;
    pid;
    shiny;
    ivs;
    ability;
    gender = Static_encounter.Genderless;
    nature;
    level = 70;
    height;
    weight;
  }

let seed_one = { Xorshift128.s0 = 1; s1 = 0; s2 = 0; s3 = 0 }
let seed_809 = { Xorshift128.s0 = 0; s1 = 0; s2 = 0; s3 = 0x809 }
let seed_mix = { Xorshift128.s0 = 0; s1 = 0; s2 = 0x809; s3 = 0x809 }

(* Golden vectors derived directly from fixtures/bdsp_rng.txt (C++
   Pokemon_BdspRng.cpp / PokeFinder 4.x StaticGenerator8b):
   - Kyogre & Groudon: Lv. 70, 3 IVs, genderless, ability_kind=3 (single
     ability Drizzle/Drought, 1 roll consumed), shiny_locked=false.
   - Regirock & Mewtwo (HA Ramanas): Lv. 70, 3 IVs, genderless, ability_kind=2
     (1 dummy roll consumed, forced HA=2), shiny_locked=false. *)
let test_golden_vectors () =
  let find_exn id = Option.get (Static_targets.find id) in
  let check_gen name seed target_id ~tsv ~sync expected =
    let target = find_exn target_id in
    let actual =
      Static_encounter.generate seed target.template ~tsv
        ~synchronize_nature:sync
    in
    check_pokemon name ~expected ~actual
  in
  let adamant = Some 3 in
  check_gen "kyogre seed_one no sync" seed_one "kyogre" ~tsv:0 ~sync:None
    (mk_pokemon ~ec:0x80000809 ~pid:0x08090809 ~shiny:Square
       ~ivs:(ivs 31 31 8 9 1 31) ~ability:0 ~nature:22 ~height:67 ~weight:66);
  check_gen "kyogre seed_one tsv 12345" seed_one "kyogre" ~tsv:12345 ~sync:None
    (mk_pokemon ~ec:0x80000809 ~pid:0x38300809 ~shiny:Square
       ~ivs:(ivs 31 31 8 9 1 31) ~ability:0 ~nature:22 ~height:67 ~weight:66);
  check_gen "kyogre seed_one sync adamant" seed_one "kyogre" ~tsv:0
    ~sync:adamant
    (mk_pokemon ~ec:0x80000809 ~pid:0x08090809 ~shiny:Square
       ~ivs:(ivs 31 31 8 9 1 31) ~ability:0 ~nature:3 ~height:71 ~weight:103);
  check_gen "groudon seed_809 no sync" seed_809 "groudon" ~tsv:0 ~sync:None
    (mk_pokemon ~ec:0x80000809 ~pid:0x08090809 ~shiny:Square
       ~ivs:(ivs 31 9 31 1 0 31) ~ability:0 ~nature:5 ~height:103 ~weight:121);
  check_gen "groudon seed_809 sync adamant" seed_809 "groudon" ~tsv:0
    ~sync:adamant
    (mk_pokemon ~ec:0x80000809 ~pid:0x08090809 ~shiny:Square
       ~ivs:(ivs 31 9 31 1 0 31) ~ability:0 ~nature:3 ~height:67 ~weight:66);
  check_gen "regirock HA seed_one no sync" seed_one "regirock" ~tsv:0 ~sync:None
    (mk_pokemon ~ec:0x80000809 ~pid:0x08090809 ~shiny:Square
       ~ivs:(ivs 31 31 8 9 1 31) ~ability:2 ~nature:22 ~height:67 ~weight:66);
  check_gen "regirock HA seed_one sync adamant" seed_one "regirock" ~tsv:0
    ~sync:adamant
    (mk_pokemon ~ec:0x80000809 ~pid:0x08090809 ~shiny:Square
       ~ivs:(ivs 31 31 8 9 1 31) ~ability:2 ~nature:3 ~height:71 ~weight:103);
  check_gen "mewtwo HA seed_mix no sync" seed_mix "mewtwo" ~tsv:0 ~sync:None
    (mk_pokemon ~ec:0x80000809 ~pid:0x08410840 ~shiny:Star
       ~ivs:(ivs 1 31 31 0 8 31) ~ability:2 ~nature:3 ~height:66 ~weight:124);
  check_gen "mewtwo HA seed_mix sync adamant" seed_mix "mewtwo" ~tsv:0
    ~sync:adamant
    (mk_pokemon ~ec:0x80000809 ~pid:0x08410840 ~shiny:Star
       ~ivs:(ivs 1 31 31 0 8 31) ~ability:2 ~nature:3 ~height:103 ~weight:121)

let test_table_invariants () =
  let check name cond =
    Table_test.report name (if cond then Ok () else Error "failed")
  in
  check "table starts with kyogre and groudon"
    (match Static_targets.all with
    | a :: b :: _ -> a.id = "kyogre" && b.id = "groudon"
    | _ -> false);
  let ids = List.map (fun (t : Static_targets.t) -> t.id) Static_targets.all in
  let unique_ids = List.sort_uniq String.compare ids in
  check "all target ids unique" (List.length ids = List.length unique_ids);
  let check_target (t : Static_targets.t) =
    let bs = t.base_stats in
    Static_targets.find t.id = Some t
    && t.template.level >= 15 && t.template.level <= 80
    && (not t.template.shiny_locked)
    && t.advances_after_accept = 84
    && bs.hp > 0 && bs.attack > 0 && bs.defense > 0 && bs.spatk > 0
    && bs.spdef > 0 && bs.speed > 0
  in
  check "all target metadata valid"
    (List.for_all check_target Static_targets.all);
  let giratina = Option.get (Static_targets.find "giratina") in
  check "giratina fixed at Lv. 70" (giratina.template.level = 70);
  let regis =
    List.map
      (fun id -> Option.get (Static_targets.find id))
      [ "regirock"; "regice"; "registeel" ]
  in
  check "ramanas regis fixed at Lv. 70 + HA"
    (List.for_all
       (fun (t : Static_targets.t) ->
         t.template.level = 70 && t.template.ability_kind = 2)
       regis);
  let rotom = Option.get (Static_targets.find "rotom") in
  check "rotom uses Direct_no_pokemon_model"
    (rotom.default_trigger = Static_targets.Direct_no_pokemon_model
    && rotom.template.guaranteed_ivs = 0)

let test_synchronize_calibration () =
  let seed =
    {
      Xorshift128.s0 = 0x1234_5678;
      s1 = 0x9abc_def0;
      s2 = 0x1357_9bdf;
      s3 = 0x2468_ace0;
    }
  in
  let timid = Some 10 in
  let check_hit target_id ~sync ~intended ~actual =
    let target = Option.get (Static_targets.find target_id) in
    let searcher =
      Static_encounter.searcher seed target.template ~tsv:0
        ~synchronize_nature:sync
    in
    let p = Static_encounter.generate_at searcher actual in
    let stats =
      Rng_calibration.expected_stats p ~base_stats:target.base_stats
        ~level:target.template.level
    in
    let observed : Rng_calibration.observed =
      {
        nature = Some p.nature;
        gender = Some p.gender;
        shiny = Some (p.shiny <> Not_shiny);
        stats =
          {
            hp = Some stats.hp;
            attack = Some stats.attack;
            defense = Some stats.defense;
            spatk = Some stats.spatk;
            spdef = Some stats.spdef;
            speed = Some stats.speed;
          };
        base_stats = target.base_stats;
        level = target.template.level;
      }
    in
    let label =
      Printf.sprintf "calibrate %s sync=%b" target_id (Option.is_some sync)
    in
    match
      Rng_calibration.identify_hit_advance ~synchronize_nature:sync seed
        target.template ~intended_advance:intended ~radius:50 observed
    with
    | Ok hit when hit.advance = actual && hit.offset = actual - intended ->
        Table_test.report label (Ok ())
    | Ok hit ->
        Table_test.report label
          (Error
             (Printf.sprintf "wrong hit %d (expected %d)" hit.advance actual))
    | Error miss -> Table_test.report label (Error miss.reason)
  in
  check_hit "kyogre" ~sync:None ~intended:200 ~actual:201;
  check_hit "kyogre" ~sync:timid ~intended:200 ~actual:197;
  check_hit "groudon" ~sync:(Some 3) ~intended:200 ~actual:204;
  check_hit "dialga" ~sync:timid ~intended:200 ~actual:201;
  check_hit "darkrai" ~sync:timid ~intended:200 ~actual:199;
  check_hit "arceus" ~sync:None ~intended:200 ~actual:204;
  (* Verify that a Synchronize-forced nature fails when calibrate omits sync. *)
  let kyogre = Option.get (Static_targets.find "kyogre") in
  let searcher =
    Static_encounter.searcher seed kyogre.template ~tsv:0
      ~synchronize_nature:timid
  in
  let p = Static_encounter.generate_at searcher 200 in
  let natural =
    Static_encounter.generate_at
      (Static_encounter.searcher seed kyogre.template ~tsv:0
         ~synchronize_nature:None)
      200
  in
  let stats =
    Rng_calibration.expected_stats p ~base_stats:kyogre.base_stats
      ~level:kyogre.template.level
  in
  let observed : Rng_calibration.observed =
    {
      nature = Some p.nature;
      gender = Some p.gender;
      shiny = Some (p.shiny <> Not_shiny);
      stats =
        {
          hp = Some stats.hp;
          attack = Some stats.attack;
          defense = Some stats.defense;
          spatk = Some stats.spatk;
          spdef = Some stats.spdef;
          speed = Some stats.speed;
        };
      base_stats = kyogre.base_stats;
      level = kyogre.template.level;
    }
  in
  let wrong_sync_rejected =
    p.nature <> natural.nature
    &&
    match
      Rng_calibration.identify_hit_advance seed kyogre.template
        ~intended_advance:200 ~radius:20 observed
    with
    | Error _ -> true
    | Ok _ -> false
  in
  Table_test.report "omitting synchronize rejects sync-forced hit"
    (if wrong_sync_rejected then Ok () else Error "unexpected match")

let () =
  test_golden_vectors ();
  test_table_invariants ();
  test_synchronize_calibration ();
  Table_test.finish ()
