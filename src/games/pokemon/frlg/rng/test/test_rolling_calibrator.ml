(* Unit tests for Rolling_calibrator: jitter damping, 10-sample window cap,
   advance convergence, and outlier rejection. *)

open Frlg_rng

let check_eq ~show name expected actual =
  if expected <> actual then (
    Printf.eprintf "FAIL %s\n  expected: %s\n  actual:   %s\n%!" name
      (show expected) (show actual);
    exit 1)

let expect_accepted name = function
  | Rolling_calibrator.Accepted { state; estimate } -> (state, estimate)
  | Rejected_outlier _ ->
      Printf.eprintf "FAIL %s: unexpectedly rejected as outlier\n%!" name;
      exit 1

let test_jitter_spike_damping () =
  (* 3 steady samples at boot_offset_ms = -100 (seed_delta_frames = 0),
     followed by a single +2 frame cold-boot jitter spike (~33.33 ms).
     Instead of jumping 100% (-33 ms to -133), the 4-sample rolling mean
     nudges gently by 1/4 (-8 ms to -108). *)
  let feed cal ~boot ~seed_delta =
    Rolling_calibrator.record cal ~used_boot_offset_ms:boot
      ~used_ingame_offset:0 ~seed_delta_frames:seed_delta ~advance_delta:0
    |> expect_accepted "steady/jitter"
  in
  let cal = Rolling_calibrator.empty in
  let cal, e1 = feed cal ~boot:(-100) ~seed_delta:0 in
  let cal, e2 = feed cal ~boot:e1.boot_offset_ms ~seed_delta:0 in
  let cal, e3 = feed cal ~boot:e2.boot_offset_ms ~seed_delta:0 in
  check_eq ~show:string_of_int "steady boot after 3 samples" (-100)
    e3.boot_offset_ms;
  check_eq ~show:string_of_int "steady count" 3 e3.sample_count;
  let _cal, e4 = feed cal ~boot:e3.boot_offset_ms ~seed_delta:2 in
  check_eq ~show:string_of_int "count after spike" 4 e4.sample_count;
  check_eq ~show:string_of_int "boot nudged gently by ~1/4 (-8 ms)" (-108)
    e4.boot_offset_ms

let test_window_cap_at_10 () =
  (* Seed 10 samples implying boot = -100, then push 10 samples implying
     boot = 0: the window must stay capped at 10 and completely forget the
     oldest -100 samples. *)
  let feed_n cal n ~boot ~seed_delta =
    let rec loop c last k =
      if k = 0 then (c, last)
      else
        let c', est =
          Rolling_calibrator.record c ~used_boot_offset_ms:boot
            ~used_ingame_offset:0 ~seed_delta_frames:seed_delta ~advance_delta:0
          |> expect_accepted "window"
        in
        loop c' est (k - 1)
    in
    loop cal { boot_offset_ms = 0; ingame_offset = 0; sample_count = 0 } n
  in
  let cal, est10 =
    feed_n Rolling_calibrator.empty 10 ~boot:(-100) ~seed_delta:0
  in
  check_eq ~show:string_of_int "capped at 10 after 10 samples" 10
    (Rolling_calibrator.count cal);
  check_eq ~show:string_of_int "mean at 10 samples" (-100) est10.boot_offset_ms;
  (* 11th sample at boot = 0 drops the oldest -100: mean = -900 / 10 = -90. *)
  let cal, est11 = feed_n cal 1 ~boot:0 ~seed_delta:0 in
  check_eq ~show:string_of_int "still capped at 10 on 11th" 10
    est11.sample_count;
  check_eq ~show:string_of_int "oldest dropped on 11th" (-90)
    est11.boot_offset_ms;
  (* 9 more samples at boot = 0 flush all remaining -100 samples. *)
  let cal, est20 = feed_n cal 9 ~boot:0 ~seed_delta:0 in
  check_eq ~show:string_of_int "still capped at 10 on 20th" 10
    (Rolling_calibrator.count cal);
  check_eq ~show:string_of_int "all old samples dropped" 0 est20.boot_offset_ms

let test_advance_convergence () =
  (* True ideal ingame_offset is -7 (odd). Start at 0 and simulate noisy
     observations with ±1 advance jitter around true -7:
       observed advance_delta = used_ingame_offset - (-7) + jitter.
     Verify the rolling mean converges cleanly to -7. *)
  let true_ideal = -7 in
  let jitters = [ 0; 1; -1; 0; 1; -1; 0; 0 ] in
  let cal, est =
    List.fold_left
      (fun (c, (prev : Rolling_calibrator.estimate)) jitter ->
        let used = prev.ingame_offset in
        let advance_delta = used - true_ideal + jitter in
        Rolling_calibrator.record c ~used_boot_offset_ms:0
          ~used_ingame_offset:used ~seed_delta_frames:0 ~advance_delta
        |> expect_accepted "advance")
      ( Rolling_calibrator.empty,
        { boot_offset_ms = 0; ingame_offset = 0; sample_count = 0 } )
      jitters
  in
  check_eq ~show:string_of_int "sample count" (List.length jitters)
    (Rolling_calibrator.count cal);
  check_eq ~show:string_of_int "converged to -7" true_ideal est.ingame_offset

let test_outlier_rejection () =
  let cal, est1 =
    Rolling_calibrator.record Rolling_calibrator.empty
      ~used_boot_offset_ms:(-50) ~used_ingame_offset:4 ~seed_delta_frames:0
      ~advance_delta:0
    |> expect_accepted "baseline"
  in
  check_eq ~show:string_of_int "baseline boot" (-50) est1.boot_offset_ms;
  let is_rejected = function
    | Rolling_calibrator.Rejected_outlier _ -> true
    | Accepted _ -> false
  in
  check_eq ~show:string_of_bool "rejects seed_delta > 30" true
    (is_rejected
       (Rolling_calibrator.record cal ~used_boot_offset_ms:(-50)
          ~used_ingame_offset:4 ~seed_delta_frames:31 ~advance_delta:0));
  check_eq ~show:string_of_bool "rejects seed_delta < -30" true
    (is_rejected
       (Rolling_calibrator.record cal ~used_boot_offset_ms:(-50)
          ~used_ingame_offset:4 ~seed_delta_frames:(-31) ~advance_delta:0));
  check_eq ~show:string_of_bool "rejects advance_delta > 50" true
    (is_rejected
       (Rolling_calibrator.record cal ~used_boot_offset_ms:(-50)
          ~used_ingame_offset:4 ~seed_delta_frames:0 ~advance_delta:51));
  check_eq ~show:string_of_bool "accepts boundary 30 / 50" false
    (is_rejected
       (Rolling_calibrator.record cal ~used_boot_offset_ms:(-50)
          ~used_ingame_offset:4 ~seed_delta_frames:30 ~advance_delta:(-50)));
  check_eq ~show:string_of_int "original calibrator untouched" 1
    (Rolling_calibrator.count cal)

let switch_seeds_path = "../../assets/rng_seeds_switch_fr_eng.json"
let encounter_slots_path = "../../assets/encounter_slots_firered.json"
let console_b_tid_xor_sid = 15287 lxor 51290
let min_adv = 900
let max_adv = 4000

let load_switch_column () =
  match Seeds_database.of_json (Yojson.Safe.from_file switch_seeds_path) with
  | Error e -> failwith e
  | Ok db -> (
      match
        List.find_opt
          (fun (c : Seeds_database.column) -> c.name = "Mono / Help / A")
          db.columns
      with
      | Some c -> (db.delays, c.seeds)
      | None -> failwith "missing Mono / Help / A column")

let load_slots ~kind ~location =
  match
    Encounters_database.of_json (Yojson.Safe.from_file encounter_slots_path)
  with
  | Error e -> failwith e
  | Ok db -> (
      match Encounters_database.slots db ~kind ~location with
      | Some s -> s
      | None -> failwith ("missing slots for " ^ kind ^ "/" ^ location))

(* Switch 2-adv/frame hardware model calibrated from Console B live runs:
   csf_offset adds 0 advances on Switch, and each overworld frame advances the
   RNG by 2 from a fixed per-location hardware baseline [hw_base]. *)
let switch_hardware_advance ~hw_base (timings : Rng_timings.t) =
  let dur = Rng_timings.switch.frame_duration_ms in
  let frames =
    int_of_float (Float.round (float_of_int timings.ingame_delay_ms /. dur))
  in
  hw_base + (2 * frames)

let switch_calibrations ingame_offset =
  let csf_offset = ingame_offset land 1 in
  {
    Rng_timings.no_calibrations with
    csf_offset;
    ingame_offset = ingame_offset - csf_offset;
  }

let simulate_switch_hunt ~delays ~seeds ~kind ~location ~species ~expected_seed
    ~expected_adv ~hw_base ~start_offset ~max_attempts =
  let slots = load_slots ~kind ~location in
  let find_target ~exclude_targets ingame_offset =
    let calibrations = switch_calibrations ingame_offset in
    Wild_target.find ~calibrations ~exclude_targets Rng_timings.switch ~delays
      ~seeds slots ~species ~tid_xor_sid:console_b_tid_xor_sid
      ~min_advance:min_adv ~max_advance:max_adv
    |> Option.get
  in
  let first = find_target ~exclude_targets:[] start_offset in
  check_eq ~show:(Printf.sprintf "0x%04X")
    (species ^ " initial seed")
    expected_seed first.seed;
  check_eq ~show:string_of_int
    (species ^ " initial advance")
    expected_adv first.advance;
  let rec loop attempt cal excluded ingame_offset =
    if attempt > max_attempts then Error "did not converge within max_attempts"
    else
      let tgt = find_target ~exclude_targets:excluded ingame_offset in
      let landed = switch_hardware_advance ~hw_base tgt.timings in
      let delta = landed - tgt.advance in
      if delta = 0 then Ok (attempt, List.length excluded, tgt.seed, tgt.advance)
      else
        let cal', est =
          Rolling_calibrator.record cal ~used_boot_offset_ms:0
            ~used_ingame_offset:ingame_offset ~seed_delta_frames:0
            ~advance_delta:delta
          |> expect_accepted species
        in
        if Rolling_calibrator.parity_locked cal' then
          loop (attempt + 1)
            (Rolling_calibrator.reset cal')
            ((tgt.seed, tgt.advance) :: excluded)
            est.ingame_offset
        else loop (attempt + 1) cal' excluded est.ingame_offset
  in
  loop 1 Rolling_calibrator.empty [] start_offset

let test_console_b_five_targets () =
  let delays, seeds = load_switch_column () in
  let cases =
    [
      ("oddish", "grass", "route_7", 0xA533, 1635, 577, false);
      ("growlithe", "grass", "route_7", 0x1E44, 1705, 577, false);
      ("psyduck", "surfing", "viridian_city", 0x1E1B, 1652, 576, false);
      ("ekans", "grass", "route_10", 0xB574, 2013, 577, false);
      ("electabuzz", "grass", "power_plant", 0x4ADF, 1732, 577, true);
    ]
  in
  List.iter
    (fun ( species,
           kind,
           location,
           expected_seed,
           expected_adv,
           hw_base,
           expect_switch ) ->
      match
        simulate_switch_hunt ~delays ~seeds ~kind ~location ~species
          ~expected_seed ~expected_adv ~hw_base ~start_offset:(-25)
          ~max_attempts:20
      with
      | Ok (attempts, skipped, seed, adv) ->
          Printf.printf
            "  %-10s converged in %d attempt(s) (skipped=%d) on %04X/%d\n%!"
            species attempts skipped seed adv;
          if expect_switch then (
            check_eq ~show:string_of_bool
              (species ^ " skipped parity-locked target")
              true (skipped >= 1);
            check_eq ~show:string_of_bool
              (species ^ " switched off 4ADF/1732")
              true
              (seed <> expected_seed || adv <> expected_adv))
          else (
            check_eq ~show:string_of_int
              (species ^ " skipped 0 targets")
              0 skipped;
            check_eq ~show:(Printf.sprintf "0x%04X")
              (species ^ " stayed on seed")
              expected_seed seed;
            check_eq ~show:string_of_int
              (species ^ " stayed on advance")
              expected_adv adv)
      | Error msg ->
          Printf.eprintf "FAIL %s (%04X/%d): %s\n%!" species expected_seed
            expected_adv msg;
          exit 1)
    cases

let test_parity_lock_unit () =
  let feed cal ~used ~delta =
    Rolling_calibrator.record cal ~used_boot_offset_ms:0
      ~used_ingame_offset:used ~seed_delta_frames:0 ~advance_delta:delta
    |> expect_accepted "parity_unit"
    |> fst
  in
  (* 2 bracketing samples are not yet enough (< 3). *)
  let c1 = feed Rolling_calibrator.empty ~used:(-25) ~delta:(-1) in
  let c2 = feed c1 ~used:(-24) ~delta:1 in
  check_eq ~show:string_of_bool "2 samples not parity locked" false
    (Rolling_calibrator.parity_locked c2);
  (* 3rd sample completing -1/+1/-1 bracket triggers parity lock. *)
  let c3 = feed c2 ~used:(-25) ~delta:(-1) in
  check_eq ~show:string_of_bool "3 bracketing samples trigger parity lock" true
    (Rolling_calibrator.parity_locked c3);
  (* Reset clears parity lock and sample count. *)
  let reset_c = Rolling_calibrator.reset c3 in
  check_eq ~show:string_of_bool "reset clears parity lock" false
    (Rolling_calibrator.parity_locked reset_c);
  check_eq ~show:string_of_int "reset clears count" 0
    (Rolling_calibrator.count reset_c);
  (* Same-side misses (-1, -1, -1) do not trigger parity lock. *)
  let same_side =
    Rolling_calibrator.empty
    |> feed ~used:(-25) ~delta:(-1)
    |> feed ~used:(-25) ~delta:(-1)
    |> feed ~used:(-25) ~delta:(-1)
  in
  check_eq ~show:string_of_bool "same-side -1 misses not parity locked" false
    (Rolling_calibrator.parity_locked same_side);
  (* Having ever hit advance_delta = 0 in the window prevents parity lock. *)
  let hit_zero =
    Rolling_calibrator.empty |> feed ~used:(-24) ~delta:0
    |> feed ~used:(-25) ~delta:(-1)
    |> feed ~used:(-24) ~delta:1
    |> feed ~used:(-25) ~delta:(-1)
  in
  check_eq ~show:string_of_bool "prior exact hit prevents parity lock" false
    (Rolling_calibrator.parity_locked hit_zero)

(* Slice 2: mGBA (1 advance/frame) never triggers parity-lock target switching
   and converges cleanly on both odd and even advances. *)
let test_mgba_non_regression () =
  let dur = Rng_timings.mgba.frame_duration_ms in
  let mgba_hw_advance ~hw_base (timings : Rng_timings.t) =
    let frames =
      int_of_float (Float.round (float_of_int timings.ingame_delay_ms /. dur))
    in
    hw_base + frames
  in
  let check_target ~label ~target_adv ~hw_base =
    let rec loop attempt cal ingame_offset =
      if attempt > 10 then (
        Printf.eprintf "FAIL mgba %s: did not converge\n%!" label;
        exit 1)
      else
        let cals = { Rng_timings.no_calibrations with ingame_offset } in
        let timings =
          Rng_timings.sweet_scent Rng_timings.mgba ~seed_delay_ms:30756
            ~advances:target_adv ~use_teachy_tv:false cals
          |> Result.get_ok
        in
        let landed = mgba_hw_advance ~hw_base timings in
        let delta = landed - target_adv in
        if delta = 0 then attempt
        else
          let cal', est =
            Rolling_calibrator.record cal ~used_boot_offset_ms:0
              ~used_ingame_offset:ingame_offset ~seed_delta_frames:0
              ~advance_delta:delta
            |> expect_accepted label
          in
          check_eq ~show:string_of_bool
            (label ^ " never parity-locks on mGBA")
            false
            (Rolling_calibrator.parity_locked cal');
          loop (attempt + 1) cal' est.ingame_offset
    in
    let attempts = loop 1 Rolling_calibrator.empty 0 in
    Printf.printf "  mgba %-6s (adv=%d) converged in %d attempt(s)\n%!" label
      target_adv attempts
  in
  check_target ~label:"odd" ~target_adv:1555 ~hw_base:390;
  check_target ~label:"even" ~target_adv:1556 ~hw_base:390

let () =
  test_jitter_spike_damping ();
  test_window_cap_at_10 ();
  test_advance_convergence ();
  test_outlier_rejection ();
  test_parity_lock_unit ();
  test_console_b_five_targets ();
  test_mgba_non_regression ();
  print_endline "rolling_calibrator: all passed"
