(* Unit tests for Rng_miss_search: Method 1 and wild-encounter miss-distance
   search, expanding advance radius, miss report formatting, and damped
   calibration deltas. Uses synthetic seed/delay tables and reads
   base_stats.json directly; no fakes. *)

open Frlg_rng

let check_eq ~show name expected actual =
  if expected <> actual then (
    Printf.eprintf "FAIL %s\n  expected: %s\n  actual:   %s\n%!" name
      (show expected) (show actual);
    exit 1)

let test_miss_search () =
  let db =
    Result.get_ok (Base_stats.load ~path:"../../assets/base_stats.json" ())
  in
  let scyther = Option.get (Base_stats.find db "scyther") in
  let delays = [| 30000; 30017; 30033; 30050; 30067 |] in
  let seeds = [| 0x1166; 0x1167; 0x1168; 0x1169; 0x116A |] in
  let target_seed_index = 2 in
  let target_advance = 1297 in

  (* Synthesize a miss at seed_index = 3 (+1 frame / +17 ms), advance = 1337 (+40 adv). *)
  let actual_seed = seeds.(3) in
  let actual_advance = 1337 in
  let state =
    Rng_state.of_seed ~seed:actual_seed ~advance:actual_advance Method1
  in
  let gen = Pokemon_generation.pokemon_of_state state in
  let computed_stats =
    Base_stats.compute_stats ~base:scyther.base ~nature:gen.nature ~ivs:gen.ivs
      ~level:25
  in
  let obs_gender : Rng_miss_search.gender =
    match
      Base_stats.gender_of_pid ~pid:gen.pid
        ~gender_threshold:scyther.gender_threshold
    with
    | Male -> Male
    | Female -> Female
    | Genderless -> Genderless
  in
  let obs : Rng_miss_search.observation =
    {
      nature = Some gen.nature;
      gender = obs_gender;
      level = 25;
      stats = Some computed_stats;
    }
  in
  let hits =
    Rng_miss_search.search_method1 ~base_stats:scyther ~delays ~seeds
      ~target_seed_index ~target_advance obs
  in
  check_eq ~show:string_of_int "found exact hit" 1 (List.length hits);
  let h = List.hd hits in
  check_eq ~show:string_of_int "hit seed" actual_seed h.seed;
  check_eq ~show:string_of_int "hit advance" actual_advance h.advance;
  check_eq ~show:string_of_int "seed_delta_frames" 1 h.seed_delta_frames;
  check_eq ~show:string_of_int "delay_delta_ms" 17 h.delay_delta_ms;
  check_eq ~show:string_of_int "advance_delta" 40 h.advance_delta;

  let boot_delta_ms, ingame_delta =
    Rng_miss_search.calibration_delta_of_hit h
  in
  check_eq ~show:string_of_int "boot_delta_ms" (-17) boot_delta_ms;
  check_eq ~show:string_of_int "ingame_delta" (-40) ingame_delta;

  let report =
    Rng_miss_search.format_miss_report ~target_seed:seeds.(target_seed_index)
      ~target_delay_ms:delays.(target_seed_index) ~target_advance hits
  in
  check_eq ~show:Fun.id "miss report"
    "RNG miss: hit seed 1169 (+1 frames / +17 ms), advance 1337 (+40 adv) [1 \
     match]"
    report;

  (* Expanding search: miss by +400 advances (> default 256) still found. *)
  let far_adv = target_advance + 400 in
  let far_gen =
    Pokemon_generation.pokemon_of_state
      (Rng_state.of_seed ~seed:seeds.(2) ~advance:far_adv Method1)
  in
  let far_stats =
    Base_stats.compute_stats ~base:scyther.base ~nature:far_gen.nature
      ~ivs:far_gen.ivs ~level:25
  in
  let far_obs : Rng_miss_search.observation =
    {
      nature = Some far_gen.nature;
      gender = Unknown;
      level = 25;
      stats = Some far_stats;
    }
  in
  let far_hits =
    Rng_miss_search.search_method1 ~base_stats:scyther ~delays ~seeds
      ~target_seed_index ~target_advance far_obs
  in
  check_eq ~show:string_of_bool "expanding search finds +400 adv" true
    (List.exists
       (fun (x : Rng_miss_search.hit) -> x.advance = far_adv)
       far_hits)

let test_damped_calibration_delta () =
  let make_hit ~seed_delta_frames ~delay_delta_ms ~advance_delta :
      Rng_miss_search.hit =
    {
      seed_index = 2 + seed_delta_frames;
      seed = 0x1168;
      delay_ms = 30033 + delay_delta_ms;
      advance = 1297 + advance_delta;
      pid = 0l;
      seed_delta_frames;
      delay_delta_ms;
      advance_delta;
    }
  in
  let show_pair (b, i) = Printf.sprintf "(%d, %d)" b i in
  let h_plus =
    make_hit ~seed_delta_frames:1 ~delay_delta_ms:18 ~advance_delta:4
  in
  let h_minus =
    make_hit ~seed_delta_frames:(-1) ~delay_delta_ms:(-15) ~advance_delta:(-2)
  in
  check_eq ~show:show_pair "no prev: full step" (-18, -4)
    (Rng_miss_search.damped_calibration_delta ~prev_seed_delta:None h_plus);
  check_eq ~show:show_pair "same sign +1 -> +1: full step" (-18, -4)
    (Rng_miss_search.damped_calibration_delta ~prev_seed_delta:(Some 1) h_plus);
  check_eq ~show:show_pair "large prev -2 -> +1: full step" (-18, -4)
    (Rng_miss_search.damped_calibration_delta ~prev_seed_delta:(Some (-2))
       h_plus);
  check_eq ~show:show_pair "flip -1 -> +1 (+18 ms): halved to -9 ms" (-9, -4)
    (Rng_miss_search.damped_calibration_delta ~prev_seed_delta:(Some (-1))
       h_plus);
  check_eq ~show:show_pair "flip +1 -> -1 (-15 ms): halved to +7 ms" (7, 2)
    (Rng_miss_search.damped_calibration_delta ~prev_seed_delta:(Some 1) h_minus);
  let h_zero =
    make_hit ~seed_delta_frames:0 ~delay_delta_ms:0 ~advance_delta:3
  in
  check_eq ~show:show_pair "zero seed miss: 0 boot delta" (0, -3)
    (Rng_miss_search.damped_calibration_delta ~prev_seed_delta:(Some 1) h_zero)

let test_search_wild () =
  let db =
    Result.get_ok (Base_stats.load ~path:"../../assets/base_stats.json" ())
  in
  let slots : Wild_encounter.slot array =
    [|
      { species = "pidgey"; min_level = 19; max_level = 22 };
      { species = "meowth"; min_level = 17; max_level = 20 };
      { species = "oddish"; min_level = 19; max_level = 22 };
      { species = "growlithe"; min_level = 18; max_level = 20 };
      { species = "pidgey"; min_level = 20; max_level = 22 };
      { species = "meowth"; min_level = 18; max_level = 20 };
      { species = "oddish"; min_level = 20; max_level = 22 };
      { species = "growlithe"; min_level = 18; max_level = 20 };
      { species = "meowth"; min_level = 19; max_level = 20 };
      { species = "growlithe"; min_level = 19; max_level = 20 };
      { species = "meowth"; min_level = 20; max_level = 20 };
      { species = "growlithe"; min_level = 20; max_level = 20 };
    |]
  in
  let delays = [| 30000; 30017; 30033; 30050; 30067 |] in
  let seeds = [| 0x1166; 0x1167; 0x1168; 0x1169; 0x116A |] in
  let target_seed_index = 2 in
  let target_advance = 1500 in
  let actual_seed = seeds.(3) in
  (* Find an advance where nature reroll skips multiple LCG states so that the
     post-reroll Method 1 PID advance differs from the wild encounter advance. *)
  let rec find_rerolled_adv adv =
    let state = Rng_state.of_seed ~seed:actual_seed ~advance:adv Method1 in
    let enc = Wild_encounter.pokemon_of_state state slots ~super_rod:false in
    let m1 =
      Pokemon_generation.pokemon_of_state
        (Rng_state.of_seed ~seed:actual_seed ~advance:(adv + 3) Method1)
    in
    if enc.pokemon.pid <> m1.pid then (adv, enc) else find_rerolled_adv (adv + 1)
  in
  let actual_advance, enc = find_rerolled_adv 1530 in
  let base_stats = Option.get (Base_stats.find db enc.species) in
  let computed_stats =
    Base_stats.compute_stats ~base:base_stats.base ~nature:enc.pokemon.nature
      ~ivs:enc.pokemon.ivs ~level:enc.level
  in
  let obs_gender : Rng_miss_search.gender =
    match
      Base_stats.gender_of_pid ~pid:enc.pokemon.pid
        ~gender_threshold:base_stats.gender_threshold
    with
    | Male -> Male
    | Female -> Female
    | Genderless -> Genderless
  in
  let obs : Rng_miss_search.observation =
    {
      nature = Some enc.pokemon.nature;
      gender = obs_gender;
      level = enc.level;
      stats = Some computed_stats;
    }
  in
  let wild_hits =
    Rng_miss_search.search_wild ~slots ~super_rod:false ~species:enc.species
      ~base_stats ~delays ~seeds ~target_seed_index ~target_advance obs
  in
  check_eq ~show:string_of_bool "search_wild found hit" true (wild_hits <> []);
  let h = List.hd wild_hits in
  check_eq ~show:string_of_int "wild hit seed" actual_seed h.seed;
  check_eq ~show:string_of_int "wild hit exact advance" actual_advance h.advance;
  check_eq ~show:string_of_int "wild seed_delta_frames" 1 h.seed_delta_frames;
  check_eq ~show:string_of_int "wild advance_delta"
    (actual_advance - target_advance)
    h.advance_delta;
  (* Verify search_method1 would NOT report actual_advance due to s0..s2 +
     nature reroll skipping LCG states. *)
  let m1_hits =
    Rng_miss_search.search_method1 ~base_stats ~delays ~seeds ~target_seed_index
      ~target_advance obs
  in
  check_eq ~show:string_of_bool "search_method1 differs from exact wild advance"
    true
    (match m1_hits with [] -> true | mh :: _ -> mh.advance <> actual_advance);
  (* Method 4 wild encounter is also recovered. *)
  let m4_adv = 1525 in
  let m4_state = Rng_state.of_seed ~seed:seeds.(1) ~advance:m4_adv Method4 in
  let m4_enc =
    Wild_encounter.pokemon_of_state m4_state slots ~super_rod:false
  in
  let m4_base = Option.get (Base_stats.find db m4_enc.species) in
  let m4_stats =
    Base_stats.compute_stats ~base:m4_base.base ~nature:m4_enc.pokemon.nature
      ~ivs:m4_enc.pokemon.ivs ~level:m4_enc.level
  in
  let m4_obs : Rng_miss_search.observation =
    {
      nature = Some m4_enc.pokemon.nature;
      gender = Unknown;
      level = m4_enc.level;
      stats = Some m4_stats;
    }
  in
  let m4_hits =
    Rng_miss_search.search_wild ~slots ~super_rod:false ~species:m4_enc.species
      ~base_stats:m4_base ~delays ~seeds ~target_seed_index ~target_advance
      m4_obs
  in
  check_eq ~show:string_of_bool "search_wild recovers Method 4 encounter" true
    (List.exists
       (fun (x : Rng_miss_search.hit) ->
         x.seed = seeds.(1) && x.advance = m4_adv)
       m4_hits)

let () =
  test_miss_search ();
  test_search_wild ();
  test_damped_calibration_delta ();
  print_endline "rng_miss_search: all passed"
