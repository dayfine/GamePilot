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
    "wait 33033, A 3000/0, wait 348, A 50/1450, B 50/2450, A 200/1800, A \
     200/1800, Down 200/300, Down 200/300, Down 200/300, A 200/5000, A 200/800"
    cmds

let test_run () =
  let run_case ~claim_ok ~shiny_on ~attempts ~party =
    let n = ref 0 in
    let checked_slots = ref [] in
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
      }
    in
    let r = Gift_rng.run steps ~attempts ~party in
    (r, List.rev !checked_slots)
  in
  let r1, slots1 = run_case ~claim_ok:true ~shiny_on:1 ~attempts:3 ~party:5 in
  check_eq
    ~show:(Option.value ~default:"ok")
    "shiny on attempt 1" None
    (Gift_rng.failure_code r1.end_);
  check_eq ~show:string_of_int "attempts=1" 1 r1.attempts;
  check_eq
    ~show:(fun xs -> String.concat "," (List.map string_of_int xs))
    "checked slot 6" [ 6 ] slots1;

  let r2, slots2 = run_case ~claim_ok:true ~shiny_on:2 ~attempts:3 ~party:5 in
  check_eq
    ~show:(Option.value ~default:"ok")
    "shiny on attempt 2" None
    (Gift_rng.failure_code r2.end_);
  check_eq ~show:string_of_int "attempts=2" 2 r2.attempts;
  check_eq
    ~show:(fun xs -> String.concat "," (List.map string_of_int xs))
    "checked slot 6 twice" [ 6; 6 ] slots2;

  let r3, _ = run_case ~claim_ok:true ~shiny_on:99 ~attempts:2 ~party:5 in
  check_eq
    ~show:(Option.value ~default:"ok")
    "all misses" (Some "gift_rng_not_shiny")
    (Gift_rng.failure_code r3.end_);
  check_eq ~show:string_of_int "attempts=2 on miss" 2 r3.attempts;

  let r4, _ = run_case ~claim_ok:false ~shiny_on:1 ~attempts:2 ~party:5 in
  check_eq
    ~show:(Option.value ~default:"ok")
    "claim failed" (Some "gift_rng_claim_failed")
    (Gift_rng.failure_code r4.end_);

  let r5, slots5 = run_case ~claim_ok:true ~shiny_on:1 ~attempts:2 ~party:6 in
  check_eq
    ~show:(Option.value ~default:"ok")
    "party full" (Some "gift_rng_party_full")
    (Gift_rng.failure_code r5.end_);
  check_eq ~show:string_of_int "party full checks 0 slots" 0
    (List.length slots5)

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

let () =
  test_decode ();
  test_target_and_presses ();
  test_run ();
  test_surf_request ();
  print_endline "gift_rng: all passed"
