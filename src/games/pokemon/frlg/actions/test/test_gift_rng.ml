(* Typed tests for gift_rng (Celadon Game Corner prize RNG) and surf action
   decoding. *)

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

let test_decode () =
  let fallback : Wild_rng_plan.trainer_ids =
    { tid = Some 12345; sid = Some 54321 }
  in
  (match
     Gift_rng.decode ~fallback
       (obj {|{"species": "scyther", "prize_row": "3"}|})
   with
  | Ok p ->
      check_eq ~show:Fun.id "species" "scyther" p.species;
      check_eq ~show:string_of_int "prize_row from string" 3 p.prize_row;
      check_eq ~show:string_of_int "tid from fallback" 12345 p.tid;
      check_eq ~show:string_of_int "sid from fallback" 54321 p.sid;
      check_eq ~show:Fun.id "default frame_model" "mgba" p.frame_model;
      check_eq ~show:string_of_int "default attempts" 1 p.attempts
  | Error c ->
      failwith
        ("unexpected decode error: " ^ Pokemon_engine.Failure.cause_to_string c));
  (match
     Gift_rng.decode ~fallback
       (obj
          {|{"species": "scyther", "prize_row": 3, "frame_model": "switch",
             "attempts": 5}|})
   with
  | Ok p ->
      check_eq ~show:string_of_int "prize_row from int" 3 p.prize_row;
      check_eq ~show:Fun.id "switch frame_model" "switch" p.frame_model;
      check_eq ~show:string_of_int "attempts" 5 p.attempts;
      let cal : Frlg_rng.Switch_rng_calibration.entry =
        {
          boot_offset_ms = -33;
          seed_shift = 4;
          ingame_offset = -2;
          updated_at = "2026-11-27T00:00:00Z";
        }
      in
      let p = Gift_rng.apply_calibration cal p in
      check_eq ~show:string_of_int "calibrated boot_offset_ms" (-33)
        p.boot_offset_ms;
      check_eq ~show:string_of_int "calibrated seed_shift" 4 p.seed_shift;
      check_eq ~show:string_of_int "calibrated ingame_offset" (-2)
        p.ingame_offset
  | Error c ->
      failwith
        ("unexpected decode error: " ^ Pokemon_engine.Failure.cause_to_string c));
  (match
     Gift_rng.decode ~fallback (obj {|{"species": "scyther", "prize_row": 9}|})
   with
  | Ok _ -> failwith "expected out-of-range prize_row to fail"
  | Error c ->
      check_eq ~show:Fun.id "out-of-range prize_row"
        "bad_args: gift_rng: prize_row is 9, not 0..4"
        (Pokemon_engine.Failure.cause_to_string c));
  match
    Gift_rng.decode ~fallback
      (obj {|{"species": "scyther", "prize_row": "abc"}|})
  with
  | Ok _ -> failwith "expected non-numeric prize_row to fail"
  | Error c ->
      check_eq ~show:Fun.id "non-numeric prize_row"
        "bad_args: gift_rng: prize_row is \"abc\", not a prize row (0-4)"
        (Pokemon_engine.Failure.cause_to_string c)

let test_target_and_presses () =
  let fallback : Wild_rng_plan.trainer_ids =
    { tid = Some 12345; sid = Some 54321 }
  in
  let plan =
    Result.get_ok
      (Gift_rng.decode ~fallback
         (obj {|{"species": "scyther", "prize_row": "3"}|}))
  in
  let target = Result.get_ok (Gift_rng.target plan) in
  let shiny =
    Frlg_rng.Pokemon_generation.shiny_type_of_pid target.pokemon.pid
      ~tid_xor_sid:(plan.tid lxor plan.sid)
  in
  check_eq ~show:string_of_bool "target PID is shiny" true (shiny <> Normal);
  let cmds =
    Gift_rng.blind_presses ~prize_row:3
      {
        seed_delay_ms = 33033;
        csf_delay_ms = 3348;
        teachy_delay_ms = 0;
        ingame_delay_ms = 10000;
      }
    |> List.map command_text |> String.concat ", "
  in
  check_eq ~show:Fun.id "scyther row 3 blind presses"
    "wait 33033, A 3000/0, wait 348, A 50/1450, B 50/2450, A 200/1300, A \
     200/1300, Down 100/300, Down 100/300, Down 100/300, wait 400, wait 400, A \
     200/1800, A 200/2800"
    cmds;
  check_eq ~show:Fun.id "switch resume press" "A 80/0"
    (command_text Rng_reset.switch_resume_press);
  check_eq ~show:Fun.id "switch default seeds" "rng_seeds_switch_fr_eng.json"
    (Wild_rng_plan.default_seeds_for_model "switch");
  check_eq ~show:Fun.id "mgba default seeds" "rng_seeds_mgba_sevii_save.json"
    (Wild_rng_plan.default_seeds_for_model "mgba")

let format_counters_log history =
  history |> List.rev
  |> List.map (fun items ->
         items
         |> List.map (fun (c : Wire.Watch.counter) ->
                Printf.sprintf "%s=%s" c.label c.value)
         |> String.concat " ")
  |> String.concat " -> "

let test_run () =
  let run_case ~claim_ok ~shiny_on ~attempts ~party =
    let n = ref 0 in
    let checked_slots = ref [] in
    let emitted = ref [] in
    let steps : Gift_rng.game_steps =
      {
        claim_prize =
          (fun () ->
            incr n;
            claim_ok);
        shiny_at =
          (fun slot ->
            checked_slots := slot :: !checked_slots;
            !n = shiny_on);
        log = ignore;
        show_counters = (fun items -> emitted := items :: !emitted);
      }
    in
    let r = Gift_rng.run steps ~attempts ~party in
    (r, List.rev !checked_slots, format_counters_log !emitted)
  in
  let r1, slots1, c1 =
    run_case ~claim_ok:true ~shiny_on:1 ~attempts:3 ~party:5
  in
  check_eq
    ~show:(Option.value ~default:"ok")
    "shiny on attempt 1" None
    (Gift_rng.failure_code r1.end_);
  check_eq ~show:string_of_int "attempts=1" 1 r1.attempts;
  check_eq
    ~show:(fun xs -> String.concat "," (List.map string_of_int xs))
    "checked slot 6" [ 6 ] slots1;
  check_eq ~show:Fun.id "counters for shiny on attempt 1"
    "attempt=1/3 phase=reset -> attempt=1/3 phase=summary -> attempt=1/3 \
     phase=shiny"
    c1;

  let r2, slots2, c2 =
    run_case ~claim_ok:true ~shiny_on:2 ~attempts:3 ~party:5
  in
  check_eq
    ~show:(Option.value ~default:"ok")
    "shiny on attempt 2" None
    (Gift_rng.failure_code r2.end_);
  check_eq ~show:string_of_int "attempts=2" 2 r2.attempts;
  check_eq
    ~show:(fun xs -> String.concat "," (List.map string_of_int xs))
    "checked slot 6 twice" [ 6; 6 ] slots2;
  check_eq ~show:Fun.id "counters for shiny on attempt 2"
    "attempt=1/3 phase=reset -> attempt=1/3 phase=summary -> attempt=2/3 \
     phase=reset -> attempt=2/3 phase=summary -> attempt=2/3 phase=shiny"
    c2;

  let r3, _, c3 = run_case ~claim_ok:true ~shiny_on:99 ~attempts:2 ~party:5 in
  check_eq
    ~show:(Option.value ~default:"ok")
    "all misses" (Some "gift_rng_not_shiny")
    (Gift_rng.failure_code r3.end_);
  check_eq ~show:string_of_int "attempts=2 on miss" 2 r3.attempts;
  check_eq ~show:Fun.id "counters for all misses"
    "attempt=1/2 phase=reset -> attempt=1/2 phase=summary -> attempt=2/2 \
     phase=reset -> attempt=2/2 phase=summary"
    c3;

  let r4, _, c4 = run_case ~claim_ok:false ~shiny_on:1 ~attempts:2 ~party:5 in
  check_eq
    ~show:(Option.value ~default:"ok")
    "claim failed" (Some "gift_rng_claim_failed")
    (Gift_rng.failure_code r4.end_);
  check_eq ~show:Fun.id "counters for claim failed" "attempt=1/2 phase=reset" c4;

  let r5, slots5, c5 =
    run_case ~claim_ok:true ~shiny_on:1 ~attempts:2 ~party:6
  in
  check_eq
    ~show:(Option.value ~default:"ok")
    "party full" (Some "gift_rng_party_full")
    (Gift_rng.failure_code r5.end_);
  check_eq ~show:string_of_int "party full checks 0 slots" 0
    (List.length slots5);
  check_eq ~show:Fun.id "counters for party full" "" c5

let test_surf_request () =
  match Action_requests.decode Mart_plan.empty "surf" (obj "{}") with
  | Ok Action_requests.Surf ->
      check_eq ~show:Fun.id "surf to_string" "surf onto water"
        (Action_requests.to_string Action_requests.Surf);
      check_eq
        ~show:(Option.value ~default:"none")
        "surf needs soul badge" (Some "soul")
        (Action_args.badge_needed "surf")
  | Ok other ->
      failwith ("expected Surf, got " ^ Action_requests.to_string other)
  | Error c ->
      failwith
        ("surf decode failed: " ^ Pokemon_engine.Failure.cause_to_string c)

let test_frame_model_auto_selection () =
  let fallback : Wild_rng_plan.trainer_ids =
    { tid = Some 12345; sid = Some 54321 }
  in
  check_eq ~show:Fun.id "switch backend -> switch model" "switch"
    (Wild_rng_plan.frame_model_for_backend "switch");
  check_eq ~show:Fun.id "mgba backend -> mgba model" "mgba"
    (Wild_rng_plan.frame_model_for_backend "mgba");
  check_eq ~show:Fun.id "other backend -> mgba model" "mgba"
    (Wild_rng_plan.frame_model_for_backend "view");
  let wild_omitted =
    obj
      {|{"method": "surf", "species": "psyduck", "location": "viridian_city"}|}
  in
  let wild_on_switch =
    Result.get_ok
      (Wild_rng_plan.decode ~fallback ~default_frame_model:"switch" wild_omitted)
  in
  check_eq ~show:Fun.id "wild_rng omitted on switch" "switch"
    wild_on_switch.frame_model;
  let wild_on_mgba =
    Result.get_ok
      (Wild_rng_plan.decode ~fallback ~default_frame_model:"mgba" wild_omitted)
  in
  check_eq ~show:Fun.id "wild_rng omitted on mgba" "mgba"
    wild_on_mgba.frame_model;
  let wild_explicit_mgba =
    Result.get_ok
      (Wild_rng_plan.decode ~fallback ~default_frame_model:"switch"
         (obj
            {|{"species": "ekans", "location": "route_10",
               "frame_model": "mgba"}|}))
  in
  check_eq ~show:Fun.id "wild_rng explicit mgba preserved on switch" "mgba"
    wild_explicit_mgba.frame_model;
  let wild_explicit_switch =
    Result.get_ok
      (Wild_rng_plan.decode ~fallback ~default_frame_model:"mgba"
         (obj
            {|{"species": "ekans", "location": "route_10",
               "frame_model": "switch"}|}))
  in
  check_eq ~show:Fun.id "wild_rng explicit switch preserved on mgba" "switch"
    wild_explicit_switch.frame_model;
  let gift_omitted = obj {|{"species": "scyther", "prize_row": "3"}|} in
  let gift_on_switch =
    Result.get_ok
      (Gift_rng.decode ~fallback ~default_frame_model:"switch" gift_omitted)
  in
  check_eq ~show:Fun.id "gift_rng omitted on switch" "switch"
    gift_on_switch.frame_model;
  let gift_on_mgba =
    Result.get_ok
      (Gift_rng.decode ~fallback ~default_frame_model:"mgba" gift_omitted)
  in
  check_eq ~show:Fun.id "gift_rng omitted on mgba" "mgba"
    gift_on_mgba.frame_model;
  let gift_explicit_mgba =
    Result.get_ok
      (Gift_rng.decode ~fallback ~default_frame_model:"switch"
         (obj {|{"species": "scyther", "prize_row": 3, "frame_model": "mgba"}|}))
  in
  check_eq ~show:Fun.id "gift_rng explicit mgba preserved on switch" "mgba"
    gift_explicit_mgba.frame_model;
  let gift_explicit_switch =
    Result.get_ok
      (Gift_rng.decode ~fallback ~default_frame_model:"mgba"
         (obj
            {|{"species": "scyther", "prize_row": 3, "frame_model": "switch"}|}))
  in
  check_eq ~show:Fun.id "gift_rng explicit switch preserved on mgba" "switch"
    gift_explicit_switch.frame_model

let test_miss_calibration () =
  let fallback : Wild_rng_plan.trainer_ids =
    { tid = Some 12345; sid = Some 54321 }
  in
  let plan =
    Result.get_ok
      (Gift_rng.decode ~fallback
         (obj
            {|{"species": "scyther", "prize_row": 3, "frame_model": "switch"}|}))
  in
  let target = Result.get_ok (Gift_rng.target plan) in
  let delays, seeds =
    Result.get_ok
      (Wild_rng_plan.seed_column_of ~seeds:plan.seeds
         ~seed_shift:plan.seed_shift)
  in
  let target_idx =
    Option.get
      (Frlg_rng.Rng_miss_search.find_seed_index ~delays ~seeds ~seed:target.seed
         ~table_delay_ms:target.table_delay_ms)
  in
  let miss_idx = target_idx + 1 in
  let miss_adv = target.advance + 25 in
  let gen =
    Frlg_rng.Pokemon_generation.pokemon_of_state
      (Frlg_rng.Rng_state.of_seed ~seed:seeds.(miss_idx) ~advance:miss_adv
         Method1)
  in
  let db = Result.get_ok (Frlg_rng.Base_stats.load ()) in
  let scyther = Option.get (Frlg_rng.Base_stats.find db "scyther") in
  let stats =
    Frlg_rng.Base_stats.compute_stats ~base:scyther.base ~nature:gen.nature
      ~ivs:gen.ivs ~level:25
  in
  let gender : Frlg_rng.Rng_miss_search.gender =
    match
      Frlg_rng.Base_stats.gender_of_pid ~pid:gen.pid
        ~gender_threshold:scyther.gender_threshold
    with
    | Male -> Male
    | Female -> Female
    | Genderless -> Genderless
  in
  let obs : Frlg_rng.Rng_miss_search.observation =
    { nature = Some gen.nature; gender; level = 25; stats = Some stats }
  in
  let cal_path = Filename.temp_file "gp_cal_" ".json" in
  Sys.remove cal_path;
  let logs = ref [] in
  let delta =
    Rng_miss_calibration.report_and_calibrate
      ~log:(fun s -> logs := s :: !logs)
      ~label:"Gift RNG" ~species:plan.species ~seeds:plan.seeds
      ~seed_shift:plan.seed_shift ~target_seed:target.seed
      ~target_delay_ms:target.table_delay_ms ~target_advance:target.advance
      ~persist:true ~calibration_path:cal_path obs
  in
  let expected_delay_delta = delays.(miss_idx) - target.table_delay_ms in
  check_eq
    ~show:
      (Option.fold ~none:"None" ~some:(fun (d : Rng_miss_calibration.delta) ->
           Printf.sprintf "(%d,%d,%d)" d.boot_delta_ms d.ingame_delta
             d.seed_delta_frames))
    "calibration delta"
    (Some
       {
         Rng_miss_calibration.boot_delta_ms = -expected_delay_delta;
         ingame_delta = -25;
         seed_delta_frames = 1;
       })
    delta;
  (* Oscillating -1 -> +1 miss halves boot_delta_ms when prev_seed_delta = -1. *)
  let damped_delta =
    Rng_miss_calibration.report_and_calibrate ~log:ignore ~label:"Gift RNG"
      ~species:plan.species ~seeds:plan.seeds ~seed_shift:plan.seed_shift
      ~target_seed:target.seed ~target_delay_ms:target.table_delay_ms
      ~target_advance:target.advance ~persist:false ~prev_seed_delta:(-1) obs
  in
  check_eq
    ~show:
      (Option.fold ~none:"None" ~some:(fun (d : Rng_miss_calibration.delta) ->
           Printf.sprintf "(%d,%d,%d)" d.boot_delta_ms d.ingame_delta
             d.seed_delta_frames))
    "damped calibration delta"
    (Some
       {
         Rng_miss_calibration.boot_delta_ms = -(expected_delay_delta / 2);
         ingame_delta = -25;
         seed_delta_frames = 1;
       })
    damped_delta;
  let persisted =
    Option.get
      (Result.get_ok
         (Frlg_rng.Switch_rng_calibration.load_console ~path:cal_path ()))
  in
  check_eq ~show:string_of_int "persisted boot_offset_ms"
    (-expected_delay_delta) persisted.boot_offset_ms;
  check_eq ~show:string_of_int "persisted ingame_offset" (-25)
    persisted.ingame_offset;
  let plan2 =
    Gift_rng.apply_timing_delta ~boot_delta_ms:(-expected_delay_delta)
      ~ingame_delta:(-25) plan
  in
  check_eq ~show:string_of_int "in-memory plan boot_offset_ms"
    (-expected_delay_delta) plan2.boot_offset_ms;
  check_eq ~show:string_of_int "in-memory plan ingame_offset" (-25)
    plan2.ingame_offset;
  if Sys.file_exists cal_path then Sys.remove cal_path

let test_attempt_logging () =
  let fallback : Wild_rng_plan.trainer_ids =
    { tid = Some 12345; sid = Some 54321 }
  in
  let plan =
    Result.get_ok
      (Gift_rng.decode ~fallback
         (obj {|{"species": "scyther", "prize_row": 3, "attempts": 5}|}))
  in
  let tgt = Result.get_ok (Gift_rng.target plan) in
  let logs = ref [] in
  let steps =
    Gift_rng.live_calibrated_game_steps
      ~log:(fun s -> logs := s :: !logs)
      plan tgt
  in
  let exception Stop_at_reset in
  let run_until_reset () =
    try
      Effect.Deep.try_with steps.claim_prize ()
        {
          effc =
            (fun (type a) (eff : a Effect.t) ->
              match eff with
              | Effects.Reset -> Some (fun _k -> raise Stop_at_reset)
              | _ -> None);
        }
      |> ignore
    with Stop_at_reset -> ()
  in
  run_until_reset ();
  run_until_reset ();
  let desc = Frlg_rng.Gift_target.describe tgt in
  check_eq ~show:(String.concat " | ") "gift attempt log lines"
    [
      Printf.sprintf "Gift RNG (attempt 1/5): %s." desc;
      Printf.sprintf "Gift RNG (attempt 2/5): %s." desc;
    ]
    (List.rev !logs)

let () =
  test_decode ();
  test_frame_model_auto_selection ();
  test_target_and_presses ();
  test_run ();
  test_surf_request ();
  test_miss_calibration ();
  test_attempt_logging ();
  print_endline "gift_rng: all passed"
