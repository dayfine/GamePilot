(* Unit tests for Base_stats, Rng_miss_search, and Switch_rng_calibration's
   timing refinement. *)

open Frlg_rng

let check_eq ~show name expected actual =
  if expected <> actual then (
    Printf.eprintf "FAIL %s\n  expected: %s\n  actual:   %s\n%!" name
      (show expected) (show actual);
    exit 1)

let test_base_stats () =
  let db =
    Result.get_ok (Base_stats.load ~path:"../../assets/base_stats.json" ())
  in
  let scyther = Option.get (Base_stats.find db "scyther") in
  check_eq ~show:string_of_int "scyther base hp" 70 scyther.base.hp;
  check_eq ~show:string_of_int "scyther base atk" 110 scyther.base.atk;
  check_eq ~show:string_of_int "scyther base spe" 105 scyther.base.spe;
  check_eq ~show:string_of_int "scyther gender_threshold" 126
    scyther.gender_threshold;

  (* Gender lookup matches PA/CC BaseStats.json thresholds. *)
  let show_gender = function
    | Base_stats.Male -> "Male"
    | Female -> "Female"
    | Genderless -> "Genderless"
  in
  check_eq ~show:show_gender "genderless (-2)" Genderless
    (Base_stats.gender_of_pid ~pid:0x12345600 ~gender_threshold:(-2));
  check_eq ~show:show_gender "100% male (-1)" Male
    (Base_stats.gender_of_pid ~pid:0x12345600 ~gender_threshold:(-1));
  check_eq ~show:show_gender "100% female (255)" Female
    (Base_stats.gender_of_pid ~pid:0x123456ff ~gender_threshold:255);
  check_eq ~show:show_gender "50% female at boundary 126" Female
    (Base_stats.gender_of_pid ~pid:0x0000007e ~gender_threshold:126);
  check_eq ~show:show_gender "50% male at 127" Male
    (Base_stats.gender_of_pid ~pid:0x0000007f ~gender_threshold:126);

  (* Gen 3 stat formula verification:
     Lv 25 Adamant (nature=3: +Atk, -SpA) Scyther with 31 all IVs:
     base = [70, 110, 80, 55, 80, 105]
     HP  = ((140 + 31) * 25) / 100 + 25 + 10 = 42 + 35 = 77
     Atk = (((220 + 31) * 25) / 100 + 5) * 11 / 10 = (62 + 5) * 11 / 10 = 73
     Def = ((160 + 31) * 25) / 100 + 5 = 47 + 5 = 52
     SpA = (((110 + 31) * 25) / 100 + 5) * 9 / 10 = (35 + 5) * 9 / 10 = 36
     SpD = ((160 + 31) * 25) / 100 + 5 = 47 + 5 = 52
     Spe = ((210 + 31) * 25) / 100 + 5 = 60 + 5 = 65 *)
  let ivs : Pokemon_generation.ivs =
    { hp = 31; attack = 31; defense = 31; spatk = 31; spdef = 31; speed = 31 }
  in
  let s =
    Base_stats.compute_stats ~base:scyther.base ~nature:3 ~ivs ~level:25
  in
  check_eq ~show:string_of_int "lv25 adamant scyther hp" 77 s.hp;
  check_eq ~show:string_of_int "lv25 adamant scyther atk" 73 s.atk;
  check_eq ~show:string_of_int "lv25 adamant scyther def" 52 s.def;
  check_eq ~show:string_of_int "lv25 adamant scyther spa" 36 s.spa;
  check_eq ~show:string_of_int "lv25 adamant scyther spd" 52 s.spd;
  check_eq ~show:string_of_int "lv25 adamant scyther spe" 65 s.spe;

  (* Nature lookup round-trip. *)
  check_eq
    ~show:(Option.value ~default:"none")
    "nature 20 is Calm" (Some "Calm")
    (Base_stats.nature_name 20);
  check_eq
    ~show:(Option.fold ~none:"none" ~some:string_of_int)
    "CALM -> 20" (Some 20)
    (Base_stats.nature_of_name "CALM")

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

let test_refine_timing () =
  let e0 : Switch_rng_calibration.entry =
    {
      boot_offset_ms = -10;
      seed_shift = 4;
      ingame_offset = 5;
      updated_at = "2026-11-26T00:00:00Z";
    }
  in
  let e1 =
    Switch_rng_calibration.refine_timing ~updated_at:"2026-11-27T12:00:00Z" e0
      ~boot_delta_ms:(-17) ~ingame_delta:(-40)
  in
  check_eq ~show:string_of_int "boot_offset_ms updated" (-27) e1.boot_offset_ms;
  check_eq ~show:string_of_int "seed_shift unchanged" 4 e1.seed_shift;
  check_eq ~show:string_of_int "ingame_offset updated" (-35) e1.ingame_offset;
  check_eq ~show:Fun.id "updated_at updated" "2026-11-27T12:00:00Z"
    e1.updated_at

let () =
  test_base_stats ();
  test_miss_search ();
  test_refine_timing ();
  print_endline "rng_miss_search: all passed"
