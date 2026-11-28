(* Unit tests for Base_stats: loading the committed base_stats.json asset,
   gender threshold boundaries, Gen 3 level-L stat calculation, nature
   round-trips, and JSON validation. No fakes; reads base_stats.json directly. *)

open Frlg_rng

let check_eq ~show name expected actual =
  if expected <> actual then (
    Printf.eprintf "FAIL %s\n  expected: %s\n  actual:   %s\n%!" name
      (show expected) (show actual);
    exit 1)

let show_gender = function
  | Base_stats.Male -> "Male"
  | Female -> "Female"
  | Genderless -> "Genderless"

let test_asset_lookup () =
  let db =
    Result.get_ok (Base_stats.load ~path:"../../assets/base_stats.json" ())
  in
  let scyther = Option.get (Base_stats.find db "scyther") in
  check_eq ~show:string_of_int "scyther base hp" 70 scyther.base.hp;
  check_eq ~show:string_of_int "scyther base atk" 110 scyther.base.atk;
  check_eq ~show:string_of_int "scyther base spe" 105 scyther.base.spe;
  check_eq ~show:string_of_int "scyther gender_threshold" 126
    scyther.gender_threshold;
  check_eq ~show:string_of_bool "case-insensitive trimmed lookup" true
    (Option.is_some (Base_stats.find db "  SCYTHER "));
  check_eq ~show:string_of_bool "unknown species returns None" true
    (Option.is_none (Base_stats.find db "missingno"))

let test_gender_thresholds () =
  check_eq ~show:show_gender "genderless (-2)" Genderless
    (Base_stats.gender_of_pid ~pid:0x12345600 ~gender_threshold:(-2));
  check_eq ~show:show_gender "100% male (-1)" Male
    (Base_stats.gender_of_pid ~pid:0x12345600 ~gender_threshold:(-1));
  check_eq ~show:show_gender "100% female (255)" Female
    (Base_stats.gender_of_pid ~pid:0x123456ff ~gender_threshold:255);
  check_eq ~show:show_gender "50% female at boundary 126" Female
    (Base_stats.gender_of_pid ~pid:0x0000007e ~gender_threshold:126);
  check_eq ~show:show_gender "50% male at 127" Male
    (Base_stats.gender_of_pid ~pid:0x0000007f ~gender_threshold:126)

let test_compute_stats () =
  (* Gen 3 stat formula verification:
     Lv 25 Adamant (nature=3: +Atk, -SpA) Scyther with 31 all IVs:
     base = [70, 110, 80, 55, 80, 105]
     HP  = ((140 + 31) * 25) / 100 + 25 + 10 = 42 + 35 = 77
     Atk = (((220 + 31) * 25) / 100 + 5) * 11 / 10 = (62 + 5) * 11 / 10 = 73
     Def = ((160 + 31) * 25) / 100 + 5 = 47 + 5 = 52
     SpA = (((110 + 31) * 25) / 100 + 5) * 9 / 10 = (35 + 5) * 9 / 10 = 36
     SpD = ((160 + 31) * 25) / 100 + 5 = 47 + 5 = 52
     Spe = ((210 + 31) * 25) / 100 + 5 = 60 + 5 = 65 *)
  let db =
    Result.get_ok (Base_stats.load ~path:"../../assets/base_stats.json" ())
  in
  let scyther = Option.get (Base_stats.find db "scyther") in
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

  (* Shedinja special case: base HP 1 always yields 1 HP. *)
  let shedinja_base : Base_stats.stats =
    { hp = 1; atk = 90; def = 45; spa = 30; spd = 30; spe = 40 }
  in
  let shedinja =
    Base_stats.compute_stats ~base:shedinja_base ~nature:0 ~ivs ~level:50
  in
  check_eq ~show:string_of_int "shedinja hp is always 1" 1 shedinja.hp

let test_natures_and_validation () =
  check_eq ~show:string_of_int "25 natures" 25
    (Array.length Base_stats.nature_names);
  check_eq
    ~show:(Option.value ~default:"none")
    "nature 20 is Calm" (Some "Calm")
    (Base_stats.nature_name 20);
  check_eq
    ~show:(Option.value ~default:"none")
    "nature -1 is None" None
    (Base_stats.nature_name (-1));
  check_eq
    ~show:(Option.value ~default:"none")
    "nature 25 is None" None
    (Base_stats.nature_name 25);
  check_eq
    ~show:(Option.fold ~none:"none" ~some:string_of_int)
    "CALM -> 20" (Some 20)
    (Base_stats.nature_of_name "CALM");
  check_eq
    ~show:(Option.fold ~none:"none" ~some:string_of_int)
    "unknown nature -> None" None
    (Base_stats.nature_of_name "unknown");
  check_eq ~show:string_of_bool "non-object json rejected" true
    (Result.is_error (Base_stats.of_json (`List [])))

let () =
  test_asset_lookup ();
  test_gender_thresholds ();
  test_compute_stats ();
  test_natures_and_validation ();
  print_endline "base_stats: OK"
