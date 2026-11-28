(* Typed R28 unit tests for Frlg_rng.Switch_rng_calibration: JSON codec
   round-trip, validation errors, pure refine_offset math (including 16-bit
   wraparound), Rng_timings.calibrations conversion, and file load/save/miss
   persistence under a temporary directory. *)

open Frlg_rng
module C = Switch_rng_calibration

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_eq label actual expected =
  if actual <> expected then fail (label ^ ": mismatch")

let test_json_roundtrip () =
  let entry_a : C.entry =
    {
      boot_offset_ms = -50;
      seed_shift = 0x0008;
      ingame_offset = -3;
      updated_at = "2026-11-27T00:00:00Z";
    }
  in
  let entry_b : C.entry =
    {
      boot_offset_ms = 17;
      seed_shift = 0xfffc;
      ingame_offset = 4;
      updated_at = "2026-11-27T01:23:45Z";
    }
  in
  let store =
    C.upsert
      (C.upsert [] ~console_id:"switch-b" entry_b)
      ~console_id:"switch-a" entry_a
  in
  let json = C.to_json store in
  assert_eq "round-trip store" (C.of_json json) (Ok store);
  assert_eq "find switch-a" (C.find store ~console_id:"switch-a") (Some entry_a);
  assert_eq "find switch-b trimmed"
    (C.find store ~console_id:" switch-b ")
    (Some entry_b);
  assert_eq "find missing" (C.find store ~console_id:"switch-c") None

let test_json_validation () =
  let bad_version =
    Yojson.Safe.from_string {|{"version": 99, "consoles": {}}|}
  in
  assert_eq "unsupported version" (C.of_json bad_version)
    (Error "unsupported calibration version 99 (expected 1)");
  let bad_shift =
    Yojson.Safe.from_string
      {|{"version": 1, "consoles": {"switch-a": {"boot_offset_ms": 0,
         "seed_shift": 70000, "ingame_offset": 0, "updated_at": ""}}}|}
  in
  assert_eq "seed_shift out of range" (C.of_json bad_shift)
    (Error "consoles.switch-a.seed_shift is 70000, not 0..65535");
  let missing_field =
    Yojson.Safe.from_string
      {|{"version": 1, "consoles": {"switch-a": {"boot_offset_ms": 0}}}|}
  in
  assert_eq "missing field" (C.of_json missing_field)
    (Error "consoles.switch-a: missing seed_shift")

let test_refine_offset () =
  (* Landing 4 seeds late and 5 advances late -> seed_shift +4, ingame_offset -5. *)
  let initial : C.entry =
    {
      boot_offset_ms = -33;
      seed_shift = 2;
      ingame_offset = 1;
      updated_at = "2026-11-26T00:00:00Z";
    }
  in
  let late_miss : C.miss_observation =
    {
      target_seed = 0x1000;
      observed_seed = 0x1004;
      target_advance = 1200;
      observed_advance = 1205;
    }
  in
  let refined =
    C.refine_offset ~updated_at:"2026-11-27T00:00:00Z" initial late_miss
  in
  assert_eq "late miss refined" refined
    {
      boot_offset_ms = -33;
      seed_shift = 6;
      ingame_offset = -4;
      updated_at = "2026-11-27T00:00:00Z";
    };
  (* Landing early with 16-bit seed wraparound: 0x0001 -> 0xffff (-2 mod 65536). *)
  let early_miss : C.miss_observation =
    {
      target_seed = 0x0001;
      observed_seed = 0xffff;
      target_advance = 1200;
      observed_advance = 1193;
    }
  in
  let wrapped = C.refine_offset C.empty_entry early_miss in
  assert_eq "early wraparound seed_shift" wrapped.seed_shift 0xfffe;
  assert_eq "early advance ingame_offset" wrapped.ingame_offset 7;
  (* Exact hit leaves offsets unchanged. *)
  let exact : C.miss_observation =
    {
      target_seed = 0x1234;
      observed_seed = 0x1234;
      target_advance = 1500;
      observed_advance = 1500;
    }
  in
  assert_eq "exact hit unchanged" (C.refine_offset refined exact) refined

let test_to_calibrations () =
  assert_eq "empty entry -> no_calibrations"
    (C.to_calibrations C.empty_entry)
    Rng_timings.no_calibrations;
  let cal =
    C.to_calibrations
      {
        boot_offset_ms = -50;
        seed_shift = 4;
        ingame_offset = -2;
        updated_at = "";
      }
  in
  (* -50 ms / 16.6667 ms/frame = -3 frames. *)
  assert_eq "boot_offset_ms rounded to frames" cal
    { seed_offset = -3; csf_offset = 0; ingame_offset = -2 }

let test_file_persistence () =
  let dir = Filename.temp_file "gp_switch_cal_" "" in
  Sys.remove dir;
  let path = Filename.concat (Filename.concat dir "nested") "cal.json" in
  assert_eq "missing file loads empty" (C.load ~path ()) (Ok []);
  assert_eq "missing console returns None"
    (C.load_console ~path ~console_id:"switch-a" ())
    (Ok None);
  let obs : C.miss_observation =
    {
      target_seed = 0x08f5;
      observed_seed = 0x08f9;
      target_advance = 1500;
      observed_advance = 1503;
    }
  in
  let expected : C.entry =
    {
      boot_offset_ms = 0;
      seed_shift = 4;
      ingame_offset = -3;
      updated_at = "2026-11-27T08:00:00Z";
    }
  in
  assert_eq "record_miss creates file and returns refined entry"
    (C.record_miss ~path ~console_id:"switch-a"
       ~updated_at:"2026-11-27T08:00:00Z" obs)
    (Ok expected);
  assert_eq "load_console reads back persisted entry"
    (C.load_console ~path ~console_id:"switch-a" ())
    (Ok (Some expected));
  (* Second miss accumulates on top of the persisted entry. *)
  let obs2 : C.miss_observation =
    {
      target_seed = 0x08f9;
      observed_seed = 0x08f8;
      target_advance = 1500;
      observed_advance = 1498;
    }
  in
  let expected2 : C.entry =
    {
      boot_offset_ms = 0;
      seed_shift = 3;
      ingame_offset = -1;
      updated_at = "2026-11-27T08:05:00Z";
    }
  in
  assert_eq "second miss accumulates"
    (C.record_miss ~path ~console_id:"switch-a"
       ~updated_at:"2026-11-27T08:05:00Z" obs2)
    (Ok expected2);
  Sys.remove path;
  Sys.rmdir (Filename.concat dir "nested");
  Sys.rmdir dir

let test_refine_timing_and_record () =
  let initial : C.entry =
    {
      boot_offset_ms = -50;
      seed_shift = 4;
      ingame_offset = -2;
      updated_at = "2026-11-26T00:00:00Z";
    }
  in
  let refined =
    C.refine_timing ~updated_at:"2026-11-27T09:00:00Z" initial
      ~boot_delta_ms:(-17) ~ingame_delta:3
  in
  assert_eq "refine_timing updates boot and ingame only" refined
    {
      boot_offset_ms = -67;
      seed_shift = 4;
      ingame_offset = 1;
      updated_at = "2026-11-27T09:00:00Z";
    };
  let dir = Filename.temp_file "gp_switch_cal_timing_" "" in
  Sys.remove dir;
  let path = Filename.concat dir "cal.json" in
  let expected : C.entry =
    {
      boot_offset_ms = -33;
      seed_shift = 0;
      ingame_offset = -5;
      updated_at = "2026-11-27T09:05:00Z";
    }
  in
  assert_eq "record_timing_miss persists"
    (C.record_timing_miss ~path ~console_id:"switch-b"
       ~updated_at:"2026-11-27T09:05:00Z" ~boot_delta_ms:(-33)
       ~ingame_delta:(-5) ())
    (Ok expected);
  assert_eq "load_console reads back timing miss"
    (C.load_console ~path ~console_id:"switch-b" ())
    (Ok (Some expected));
  Sys.remove path;
  Sys.rmdir dir

let () =
  test_json_roundtrip ();
  test_json_validation ();
  test_refine_offset ();
  test_to_calibrations ();
  test_file_persistence ();
  test_refine_timing_and_record ();
  print_endline "OK"
