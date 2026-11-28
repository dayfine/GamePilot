(* Tests for the static_rng game action: plan decoding, Method 1 target search,
   static encounter blind-press sequence, and attempt-loop decisions on fake
   game steps standing in for the hard reset, battle-intro visual shiny
   detector, catch runner, and party Summary shiny-star check. *)

open Frlg_actions

let obj json = Json_field.as_object "" (Yojson.Safe.from_string json)

let check_eq ~show name expected actual =
  if expected <> actual then (
    Printf.eprintf "FAIL %s\n  expected: %s\n  actual:   %s\n%!" name
      (show expected) (show actual);
    exit 1)

let command_text = function
  | Wire.Wait { wait_ms } -> Printf.sprintf "wait %d" wait_ms
  | Wire.Press { buttons; hold_ms; cooldown_ms; _ } ->
      Printf.sprintf "%s %d/%d"
        (String.concat "+" (List.map Wire.string_of_button buttons))
        hold_ms cooldown_ms

let fallback : Wild_rng_plan.trainer_ids =
  { tid = Some 12345; sid = Some 54321 }

let test_decode () =
  let p1 =
    Result.get_ok
      (Static_rng.decode ~fallback
         (obj
            {|{"species": "zapdos", "ball": "ultra-ball", "balls": 25,
               "attempts": 5, "boot_offset_ms": -30, "seed_shift": 8,
               "ingame_offset": -2, "advances": [1000, 3500],
               "catch_mode": "phase1", "visual_shiny_check": true,
               "frame_model": "switch"}|}))
  in
  check_eq ~show:Fun.id "species" "zapdos" p1.species;
  check_eq ~show:string_of_int "tid" 12345 p1.tid;
  check_eq ~show:string_of_int "sid" 54321 p1.sid;
  check_eq ~show:string_of_int "boot_offset_ms" (-30) p1.boot_offset_ms;
  check_eq ~show:string_of_int "seed_shift" 8 p1.seed_shift;
  check_eq ~show:string_of_int "ingame_offset" (-2) p1.ingame_offset;
  check_eq ~show:string_of_int "min_advance" 1000 p1.min_advance;
  check_eq ~show:string_of_int "max_advance" 3500 p1.max_advance;
  check_eq ~show:string_of_int "attempts" 5 p1.attempts;
  check_eq ~show:Fun.id "ball" "ultra-ball" p1.capture.ball;
  check_eq ~show:string_of_int "balls" 25 p1.capture.max_balls;
  check_eq ~show:string_of_bool "visual_shiny_check" true p1.visual_shiny_check;
  check_eq ~show:Fun.id "frame_model" "switch" p1.frame_model;
  (match p1.catch_mode with
  | Wild_rng_plan.Catch_policy { policy; _ } ->
      check_eq ~show:Fun.id "policy ball" "ultra-ball" policy.ball_name;
      check_eq ~show:string_of_bool "phase1 has wall" true
        (Option.is_some policy.wall)
  | Wild_rng_plan.Throw_only -> failwith "expected Catch_policy");
  let cal : Frlg_rng.Switch_rng_calibration.entry =
    {
      boot_offset_ms = -20;
      seed_shift = 4;
      ingame_offset = 3;
      updated_at = "2026-11-27T00:00:00Z";
    }
  in
  let p1_cal = Static_rng.apply_calibration cal p1 in
  check_eq ~show:string_of_int "calibrated boot_offset_ms" (-50)
    p1_cal.boot_offset_ms;
  check_eq ~show:string_of_int "calibrated seed_shift" 12 p1_cal.seed_shift;
  check_eq ~show:string_of_int "calibrated ingame_offset" 1 p1_cal.ingame_offset;
  let p_default =
    Result.get_ok
      (Static_rng.decode ~fallback ~default_frame_model:"switch"
         (obj {|{"species": "articuno"}|}))
  in
  check_eq ~show:Fun.id "default frame_model from backend" "switch"
    p_default.frame_model;
  check_eq ~show:string_of_bool "default visual_shiny_check" false
    p_default.visual_shiny_check;
  check_eq ~show:string_of_int "default attempts" 1 p_default.attempts;
  (match
     Static_rng.decode ~fallback
       (obj {|{"species": "zapdos", "catch_mode": "invalid"}|})
   with
  | Ok _ -> failwith "expected invalid catch_mode to fail"
  | Error c ->
      check_eq ~show:Fun.id "invalid catch_mode"
        "bad_args: static_rng: catch_mode is invalid, not throw_only, phase1, \
         phase2, or spore_ball"
        (Pokemon_engine.Failure.cause_to_string c));
  match
    Static_rng.decode ~fallback
      (obj {|{"species": "zapdos", "boot_offset_ms": 20000}|})
  with
  | Ok _ -> failwith "expected out-of-range boot_offset_ms to fail"
  | Error c ->
      check_eq ~show:Fun.id "out-of-range boot_offset_ms"
        "bad_args: static_rng: boot_offset_ms is 20000, not -10000..10000"
        (Pokemon_engine.Failure.cause_to_string c)

let test_target_and_presses () =
  let plan =
    Result.get_ok (Static_rng.decode ~fallback (obj {|{"species": "zapdos"}|}))
  in
  let target = Result.get_ok (Static_rng.target plan) in
  let shiny =
    Frlg_rng.Pokemon_generation.shiny_type_of_pid target.pokemon.pid
      ~tid_xor_sid:(plan.tid lxor plan.sid)
  in
  check_eq ~show:string_of_bool "target PID is shiny" true (shiny <> Normal);
  let cmds =
    Static_rng.blind_presses
      {
        seed_delay_ms = 33033;
        csf_delay_ms = 3348;
        teachy_delay_ms = 0;
        ingame_delay_ms = 12625;
      }
    |> List.map command_text |> String.concat ", "
  in
  check_eq ~show:Fun.id "static encounter blind presses"
    "wait 33033, A 3000/0, wait 348, A 50/1450, B 50/2450, Start 200/300, wait \
     7625, B 200/300, A 200/800, A 80/240, A 80/240, A 80/240"
    cmds

let caught_summary : Pokemon_catch.Catch_runner.summary =
  { turns = 5; balls_thrown = 3; switches = 1; heals = 0 }

let reading_of verdict : Frlg_readers.Shiny_encounter_reader.reading =
  { verdict; wild_intro_ms = Some 3800.; phase = Intro_complete }

let zapdos_capture =
  (Result.get_ok (Static_rng.decode ~fallback (obj {|{"species": "zapdos"}|})))
    .capture

let run_policy_case ~verdicts ~catch_outcome ~shiny_on ~attempts ~party =
  let find_n = ref 0 in
  let miss_n = ref 0 in
  let catch_n = ref 0 in
  let summary_slots = ref [] in
  let pc : Wild_rng.policy_catch_steps =
    {
      find_encounter =
        (fun () ->
          incr find_n;
          true);
      detect_shiny =
        Some
          (fun () ->
            let idx = min (!find_n - 1) (Array.length verdicts - 1) in
            reading_of verdicts.(idx));
      on_miss = (fun ~party:_ -> incr miss_n);
      catch_battle =
        (fun () ->
          incr catch_n;
          catch_outcome);
      finish_catch = (fun _ -> true);
    }
  in
  let steps : Wild_rng.game_steps =
    {
      catch = (fun _ ~party:_ -> failwith "legacy catch should not run");
      policy_catch = Some pc;
      shiny_at =
        (fun slot ->
          summary_slots := slot :: !summary_slots;
          !find_n = shiny_on);
      log = ignore;
      show_counters = ignore;
    }
  in
  let r = Static_rng.run steps ~attempts zapdos_capture ~party in
  (r, !find_n, !miss_n, !catch_n, List.rev !summary_slots)

let test_visual_shiny_and_reset_loop () =
  let open Frlg_readers.Shiny_encounter_reader in
  (* Shiny hit on attempt 1 -> catch -> summary slot 6 confirmed. *)
  let r1, finds1, misses1, catches1, slots1 =
    run_policy_case ~verdicts:[| Shiny |] ~catch_outcome:(Caught caught_summary)
      ~shiny_on:1 ~attempts:3 ~party:5
  in
  check_eq
    ~show:(Option.value ~default:"ok")
    "shiny hit on attempt 1" None
    (Static_rng.failure_code r1.end_);
  check_eq ~show:string_of_int "hit attempt count" 1 r1.attempts;
  check_eq ~show:string_of_int "hit finds" 1 finds1;
  check_eq ~show:string_of_int "hit misses" 0 misses1;
  check_eq ~show:string_of_int "hit catches" 1 catches1;
  check_eq
    ~show:(fun xs -> String.concat "," (List.map string_of_int xs))
    "hit summary slot" [ 6 ] slots1;

  (* Visual miss on attempt 1 skips catch and resets; shiny hit on attempt 2. *)
  let r2, finds2, misses2, catches2, slots2 =
    run_policy_case ~verdicts:[| Not_shiny; Shiny |]
      ~catch_outcome:(Caught caught_summary) ~shiny_on:2 ~attempts:3 ~party:5
  in
  check_eq
    ~show:(Option.value ~default:"ok")
    "visual miss then shiny hit" None
    (Static_rng.failure_code r2.end_);
  check_eq ~show:string_of_int "miss+hit attempt count" 2 r2.attempts;
  check_eq ~show:string_of_int "miss+hit finds" 2 finds2;
  check_eq ~show:string_of_int "miss+hit misses" 1 misses2;
  check_eq ~show:string_of_int "miss+hit catches" 1 catches2;
  check_eq
    ~show:(fun xs -> String.concat "," (List.map string_of_int xs))
    "miss+hit summary slot" [ 6 ] slots2;

  (* All attempts visually miss -> static_rng_not_shiny_intro, 0 catches. *)
  let r3, finds3, misses3, catches3, slots3 =
    run_policy_case ~verdicts:[| Not_shiny |]
      ~catch_outcome:(Caught caught_summary) ~shiny_on:99 ~attempts:3 ~party:5
  in
  check_eq
    ~show:(Option.value ~default:"ok")
    "all visual misses" (Some "static_rng_not_shiny_intro")
    (Static_rng.failure_code r3.end_);
  check_eq ~show:string_of_int "all misses attempts" 3 r3.attempts;
  check_eq ~show:string_of_int "all misses finds" 3 finds3;
  check_eq ~show:string_of_int "all misses on_miss count" 3 misses3;
  check_eq ~show:string_of_int "all misses catches" 0 catches3;
  check_eq ~show:string_of_int "all misses summary checks" 0
    (List.length slots3);

  (* Catch pause stops immediately without retrying. *)
  let r4, finds4, _, catches4, _ =
    run_policy_case ~verdicts:[| Shiny |]
      ~catch_outcome:
        (Paused { reason = "max turns reached"; summary = caught_summary })
      ~shiny_on:1 ~attempts:3 ~party:5
  in
  check_eq
    ~show:(Option.value ~default:"ok")
    "catch pause stops loop" (Some "static_rng_catch_paused")
    (Static_rng.failure_code r4.end_);
  check_eq ~show:string_of_int "pause finds" 1 finds4;
  check_eq ~show:string_of_int "pause catches" 1 catches4;

  (* Party full fails before the first reset. *)
  let r5, finds5, _, catches5, _ =
    run_policy_case ~verdicts:[| Shiny |] ~catch_outcome:(Caught caught_summary)
      ~shiny_on:1 ~attempts:3 ~party:6
  in
  check_eq
    ~show:(Option.value ~default:"ok")
    "party full" (Some "static_rng_party_full")
    (Static_rng.failure_code r5.end_);
  check_eq ~show:string_of_int "party full attempts" 0 r5.attempts;
  check_eq ~show:string_of_int "party full finds" 0 finds5;
  check_eq ~show:string_of_int "party full catches" 0 catches5

let test_legacy_retry_loop () =
  let n = ref 0 in
  let capture_ok : Capture.result =
    {
      end_ = All_caught;
      encounters = 1;
      balls_thrown = 2;
      caught = [ { species = Some "zapdos"; destination = Party } ];
    }
  in
  let steps : Wild_rng.game_steps =
    {
      catch =
        (fun _ ~party:_ ->
          incr n;
          capture_ok);
      policy_catch = None;
      shiny_at = (fun _ -> !n = 2);
      log = ignore;
      show_counters = ignore;
    }
  in
  let r = Static_rng.run steps ~attempts:3 zapdos_capture ~party:5 in
  check_eq
    ~show:(Option.value ~default:"ok")
    "legacy retry hits on attempt 2" None
    (Static_rng.failure_code r.end_);
  check_eq ~show:string_of_int "legacy attempts" 2 r.attempts

let test_cal_ball_row_and_exclude_targets () =
  let p =
    Result.get_ok
      (Static_rng.decode ~fallback
         (obj
            {|{"species": "zapdos", "frame_model": "switch",
               "catch_mode": "spore_ball", "cal_ball_row": 1}|}))
  in
  check_eq ~show:string_of_int "cal_ball_row" 1 p.cal_ball_row;
  check_eq ~show:string_of_bool "switch policy defaults visual_shiny_check" true
    p.visual_shiny_check;
  check_eq ~show:Fun.id "switch default seeds" "rng_seeds_switch_fr_eng.json"
    p.seeds;
  let first = Result.get_ok (Static_rng.target p) in
  let next =
    Result.get_ok
      (Static_rng.target ~exclude_targets:[ (first.seed, first.advance) ] p)
  in
  check_eq ~show:string_of_bool "exclude_targets skips first static target" true
    (next.seed <> first.seed || next.advance <> first.advance);
  let shiny =
    Frlg_rng.Pokemon_generation.shiny_type_of_pid next.pokemon.pid
      ~tid_xor_sid:(p.tid lxor p.sid)
  in
  check_eq ~show:string_of_bool "fallback static target is shiny" true
    (shiny <> Normal)

let test_method1_rolling_miss_calibration () =
  let plan =
    Result.get_ok
      (Static_rng.decode ~fallback
         (obj {|{"species": "zapdos", "frame_model": "switch"}|}))
  in
  let tgt = Result.get_ok (Static_rng.target plan) in
  let delays, seeds =
    Result.get_ok
      (Wild_rng_plan.seed_column_of ~seeds:plan.seeds
         ~seed_shift:plan.seed_shift)
  in
  let idx =
    Option.get
      (Frlg_rng.Rng_miss_search.find_seed_index ~delays ~seeds ~seed:tgt.seed
         ~table_delay_ms:tgt.table_delay_ms)
  in
  let miss_idx = idx + 1 in
  let miss_adv = tgt.advance + 15 in
  let gen =
    Frlg_rng.Pokemon_generation.pokemon_of_state
      (Frlg_rng.Rng_state.of_seed ~seed:seeds.(miss_idx) ~advance:miss_adv
         Method1)
  in
  let db = Result.get_ok (Frlg_rng.Base_stats.load ()) in
  let zapdos = Option.get (Frlg_rng.Base_stats.find db "zapdos") in
  let stats =
    Frlg_rng.Base_stats.compute_stats ~base:zapdos.base ~nature:gen.nature
      ~ivs:gen.ivs ~level:50
  in
  let obs : Frlg_rng.Rng_miss_search.observation =
    {
      nature = Some gen.nature;
      gender = Genderless;
      level = 50;
      stats = Some stats;
    }
  in
  let cal_path = Filename.temp_file "gp_static_cal_" ".json" in
  Sys.remove cal_path;
  let logs = ref [] in
  let res =
    Rng_miss_calibration.report_and_calibrate_method1_rolling
      ~log:(fun s -> logs := s :: !logs)
      ~label:"Static RNG (attempt 1/5)" ~species:plan.species ~seeds:plan.seeds
      ~seed_shift:plan.seed_shift ~target_seed:tgt.seed
      ~target_delay_ms:tgt.table_delay_ms ~target_advance:tgt.advance
      ~persist:true ~calibrator:Frlg_rng.Rolling_calibrator.empty
      ~used_boot_offset_ms:0 ~used_ingame_offset:0 ~calibration_path:cal_path
      obs
  in
  let _cal, est = Option.get res in
  let expected_boot = -(delays.(miss_idx) - tgt.table_delay_ms) in
  check_eq ~show:string_of_int "rolling sample_count" 1 est.sample_count;
  check_eq ~show:string_of_int "rolling boot_offset_ms" expected_boot
    est.boot_offset_ms;
  check_eq ~show:string_of_int "rolling ingame_offset" (-15) est.ingame_offset;
  let persisted =
    Option.get
      (Result.get_ok
         (Frlg_rng.Switch_rng_calibration.load_console ~path:cal_path ()))
  in
  check_eq ~show:string_of_int "persisted boot_offset_ms" expected_boot
    persisted.boot_offset_ms;
  check_eq ~show:string_of_int "persisted ingame_offset" (-15)
    persisted.ingame_offset;
  if Sys.file_exists cal_path then Sys.remove cal_path

let test_watch_counters_and_attempt_logging () =
  let emitted = ref [] in
  let find_n = ref 0 in
  let pc : Wild_rng.policy_catch_steps =
    {
      find_encounter =
        (fun () ->
          incr find_n;
          true);
      detect_shiny =
        Some
          (fun () ->
            if !find_n = 1 then reading_of Not_shiny else reading_of Shiny);
      on_miss = (fun ~party:_ -> ());
      catch_battle = (fun () -> Caught caught_summary);
      finish_catch = (fun _ -> true);
    }
  in
  let steps : Wild_rng.game_steps =
    {
      catch = (fun _ ~party:_ -> failwith "unused");
      policy_catch = Some pc;
      shiny_at = (fun _ -> true);
      log = ignore;
      show_counters = (fun items -> emitted := items :: !emitted);
    }
  in
  let r = Static_rng.run steps ~attempts:3 zapdos_capture ~party:5 in
  check_eq
    ~show:(Option.value ~default:"ok")
    "counter test shiny" None
    (Static_rng.failure_code r.end_);
  let formatted =
    !emitted |> List.rev
    |> List.map (fun items ->
           items
           |> List.map (fun (c : Wire.Watch.counter) ->
                  Printf.sprintf "%s=%s" c.label c.value)
           |> String.concat " ")
    |> String.concat " -> "
  in
  check_eq ~show:Fun.id "static_rng watch counters"
    "attempt=1/3 phase=reset -> attempt=1/3 phase=encounter -> attempt=2/3 \
     phase=reset -> attempt=2/3 phase=encounter -> attempt=2/3 phase=catch -> \
     attempt=2/3 phase=summary -> attempt=2/3 phase=shiny"
    formatted

let () =
  test_decode ();
  test_target_and_presses ();
  test_visual_shiny_and_reset_loop ();
  test_legacy_retry_loop ();
  test_cal_ball_row_and_exclude_targets ();
  test_method1_rolling_miss_calibration ();
  test_watch_counters_and_attempt_logging ();
  print_endline "static_rng: all passed"
