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

let () =
  test_jitter_spike_damping ();
  test_window_cap_at_10 ();
  test_advance_convergence ();
  test_outlier_rejection ();
  print_endline "rolling_calibrator: all passed"
