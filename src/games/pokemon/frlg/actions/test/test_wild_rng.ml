(* The wild_rng action: its args (pure), the blind presses for a target's
   timings (the fork's reset_and_perform_blind_sequence for Sweet Scent), and
   its decisions on fake game steps. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }
let obj json = Json_field.as_object "" (Yojson.Safe.from_string json)

let plan_args =
  {|{"species": "ekans", "location": "route_10", "tid": 12345, "sid": 54321,
     "seeds": "rng_seeds_mgba_sevii_save.json", "seed_shift": 8,
     "frame_model": "mgba",
     "advances": [900, 4000], "ball": "poke-ball", "balls": 8}|}

let plan_args_no_ids =
  {|{"species": "ekans", "location": "route_10",
     "seeds": "rng_seeds_mgba_sevii_save.json", "seed_shift": 8,
     "frame_model": "mgba",
     "advances": [900, 4000], "ball": "poke-ball", "balls": 8}|}

let options_of pairs =
  let decl : Run_options.declared list =
    [
      {
        key = "tid";
        value = Int_range (0, 0xffff);
        presence = Optional;
        doc = "";
      };
      {
        key = "sid";
        value = Int_range (0, 0xffff);
        presence = Optional;
        doc = "";
      };
      {
        key = "ball";
        value =
          One_of [ "poke-ball"; "great-ball"; "ultra-ball"; "luxury-ball" ];
        presence = Optional;
        doc = "";
      };
      {
        key = "balls";
        value = Int_range (1, 999);
        presence = Optional;
        doc = "";
      };
      {
        key = "catch_mode";
        value = One_of [ "throw_only"; "phase1"; "phase2" ];
        presence = Optional;
        doc = "";
      };
      {
        key = "attempts";
        value = Int_range (1, 99);
        presence = Optional;
        doc = "";
      };
    ]
  in
  Result.get_ok (Run_options.check decl pairs)

let decode ?options ?fallback json () =
  match Wild_rng_plan.decode ?options ?fallback (obj json) with
  | Ok t ->
      Printf.sprintf
        "%s at %s, ids %d/%d, %s + %d (%s), advances %d..%d, in-game %d: %s"
        t.species t.location t.tid t.sid t.seeds t.seed_shift t.frame_model
        t.min_advance t.max_advance t.ingame_offset
        (Capture_plan.describe t.capture)
  | Error c -> Pokemon_engine.Failure.cause_to_string c

let decoding =
  [
    case "plan args with inline ids" (decode plan_args)
      "ekans at route_10, ids 12345/54321, rng_seeds_mgba_sevii_save.json + 8 \
       (mgba), advances 900..4000, in-game 0: 1 ekans, 1 encounters, 8 \
       poke-ball";
    case "ids from --options when omitted from plan"
      (decode
         ~options:(options_of [ ("tid", "42"); ("sid", "99") ])
         plan_args_no_ids)
      "ekans at route_10, ids 42/99, rng_seeds_mgba_sevii_save.json + 8 \
       (mgba), advances 900..4000, in-game 0: 1 ekans, 1 encounters, 8 \
       poke-ball";
    case "ball and balls overridden by --options"
      (decode
         ~options:
           (options_of
              [
                ("tid", "42");
                ("sid", "99");
                ("ball", "great-ball");
                ("balls", "12");
              ])
         plan_args_no_ids)
      "ekans at route_10, ids 42/99, rng_seeds_mgba_sevii_save.json + 8 \
       (mgba), advances 900..4000, in-game 0: 1 ekans, 1 encounters, 12 \
       great-ball";
    case "--options overrides plan and fallback"
      (decode
         ~options:(options_of [ ("tid", "7"); ("sid", "8") ])
         ~fallback:{ tid = Some 10; sid = Some 20 }
         plan_args)
      "ekans at route_10, ids 7/8, rng_seeds_mgba_sevii_save.json + 8 (mgba), \
       advances 900..4000, in-game 0: 1 ekans, 1 encounters, 8 poke-ball";
    case "fallback used when plan and --options omit ids"
      (decode ~fallback:{ tid = Some 10; sid = Some 20 } plan_args_no_ids)
      "ekans at route_10, ids 10/20, rng_seeds_mgba_sevii_save.json + 8 \
       (mgba), advances 900..4000, in-game 0: 1 ekans, 1 encounters, 8 \
       poke-ball";
    case "missing tid fails clearly" (decode plan_args_no_ids)
      "bad_args: wild_rng: missing tid (pass --options tid=N, set \
       GAMEPILOT_FRLG_TID, or set it in trainer_ids.json)";
    case "missing sid fails clearly"
      (decode ~fallback:{ tid = Some 10; sid = None } plan_args_no_ids)
      "bad_args: wild_rng: missing sid (pass --options sid=N, set \
       GAMEPILOT_FRLG_SID, or set it in trainer_ids.json)";
    case "no seed_shift: 0"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "frame_model": "mgba"}|})
      "ekans at route_10, ids 1/2, x.json + 0 (mgba), advances 900..4000, \
       in-game 0: 1 ekans, 1 encounters, 5 poke-ball";
    case "an ingame_offset"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "ingame_offset": -1, "frame_model": "mgba"}|})
      "ekans at route_10, ids 1/2, x.json + 0 (mgba), advances 900..4000, \
       in-game -1: 1 ekans, 1 encounters, 5 poke-ball";
    case "an ingame_offset out of range"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "ingame_offset": 100, "frame_model": "mgba"}|})
      "bad_args: wild_rng: ingame_offset is 100, not -99..99";
    case "a seed_shift out of range"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "seed_shift": -4, "frame_model": "mgba"}|})
      "bad_args: wild_rng: seed_shift is -4, not 0..65535";
    case "a SID out of range"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 70000,
            "seeds": "x.json", "frame_model": "mgba"}|})
      "bad_args: wild_rng: sid is 70000, not 0..65535";
    case "an unknown frame model"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "frame_model": "gba"}|})
      "bad_args: wild_rng: frame_model is gba, not mgba or switch";
  ]

(* The presses as "<button> <hold>/<release>" and "wait <ms>". *)
let command_text = function
  | Wire.Wait { wait_ms } -> Printf.sprintf "wait %d" wait_ms
  | Wire.Press { buttons; hold_ms; cooldown_ms; _ } ->
      Printf.sprintf "%s %d/%d"
        (String.concat "+" (List.map Wire.string_of_button buttons))
        hold_ms cooldown_ms

let blind () =
  Wild_rng_steps.blind_presses
    {
      seed_delay_ms = 33033;
      csf_delay_ms = 3348;
      teachy_delay_ms = 0;
      ingame_delay_ms = 10129;
    }
  |> List.map command_text |> String.concat ", "

let presses =
  [
    case "the seed 08F5 target's presses" blind
      "wait 33033, A 3000/0, wait 348, A 50/1450, B 50/2450, Start 200/300, \
       Down 200/300, A 200/1000, Up 200/300, Up 200/300, A 200/300, Down \
       200/2729, A 200/800";
  ]

let capture_result end_ : Capture.result =
  {
    end_;
    encounters = 1;
    balls_thrown = 1;
    caught =
      (if end_ = Capture.All_caught then
         [ { species = Some "ekans"; destination = Party } ]
       else []);
  }

(* The steps it took, and how it ended. *)
let decide ~capture_end ~shiny ~party () =
  let steps = ref [] in
  let game_steps : Wild_rng.game_steps =
    {
      catch =
        (fun _ ~party ->
          steps := Printf.sprintf "catch (party %d)" party :: !steps;
          capture_result capture_end);
      policy_catch = None;
      shiny_at =
        (fun slot ->
          steps := Printf.sprintf "summary %d" slot :: !steps;
          shiny);
      log = ignore;
    }
  in
  let plan =
    match Wild_rng_plan.decode (obj plan_args) with
    | Ok p -> p.capture
    | Error _ -> failwith "plan"
  in
  let r = Wild_rng.run game_steps plan ~party in
  String.concat ", " (List.rev !steps)
  ^ ": "
  ^ Option.value (Wild_rng.failure_code r.end_) ~default:"passes"

let reading_of verdict : Frlg_readers.Shiny_encounter_reader.reading =
  { verdict; wild_intro_ms = Some 2750.; phase = Intro_complete }

let decide_policy ?(found = true) ?intro_verdict ~catch_outcome
    ?(finish_ok = true) ~shiny ~party () =
  let steps = ref [] in
  let add s = steps := s :: !steps in
  let detect_shiny =
    Option.map
      (fun v () ->
        add ("intro " ^ Frlg_readers.Shiny_encounter_reader.verdict_to_string v);
        reading_of v)
      intro_verdict
  in
  let pc : Wild_rng.policy_catch_steps =
    {
      find_encounter =
        (fun () ->
          add "find";
          found);
      detect_shiny;
      on_miss = (fun () -> add "on_miss");
      catch_battle =
        (fun () ->
          add "catch_battle";
          catch_outcome);
      finish_catch =
        (fun _ ->
          add "finish_catch";
          finish_ok);
    }
  in
  let game_steps : Wild_rng.game_steps =
    {
      catch = (fun _ ~party:_ -> failwith "legacy catch should not run");
      policy_catch = Some pc;
      shiny_at =
        (fun slot ->
          add (Printf.sprintf "summary %d" slot);
          shiny);
      log = ignore;
    }
  in
  let plan =
    match Wild_rng_plan.decode (obj plan_args) with
    | Ok p -> p.capture
    | Error _ -> failwith "plan"
  in
  let r = Wild_rng.run game_steps plan ~party in
  let cap_balls =
    match r.capture with
    | None -> "none"
    | Some c -> Printf.sprintf "%d" c.balls_thrown
  in
  Printf.sprintf "%s => %s (balls=%s)"
    (String.concat ", " (List.rev !steps))
    (Option.value (Wild_rng.failure_code r.end_) ~default:"passes")
    cap_balls

let caught_summary : Pokemon_catch.Catch_runner.summary =
  { turns = 4; balls_thrown = 2; switches = 1; heals = 0 }

let policy_decoding =
  let decode_mode json () =
    match Wild_rng_plan.decode (obj json) with
    | Ok t ->
        let mode =
          match t.catch_mode with
          | Throw_only -> "throw_only"
          | Catch_policy { policy; _ } ->
              Printf.sprintf "policy(ball=%s,wall=%b)" policy.ball_name
                (Option.is_some policy.wall)
        in
        Printf.sprintf "%s visual=%b boot=%d shift=%d ingame=%d" mode
          t.visual_shiny_check t.boot_offset_ms t.seed_shift t.ingame_offset
    | Error c -> Pokemon_engine.Failure.cause_to_string c
  in
  let decode_calibrated () =
    match
      Wild_rng_plan.decode
        (obj
           {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
              "seeds": "x.json", "frame_model": "switch",
              "catch_mode": "phase1", "visual_shiny_check": true,
              "ball": "luxury-ball"}|})
    with
    | Ok t ->
        let cal : Frlg_rng.Switch_rng_calibration.entry =
          {
            boot_offset_ms = -50;
            seed_shift = 4;
            ingame_offset = -2;
            updated_at = "2026-11-27T00:00:00Z";
          }
        in
        let t = Wild_rng_plan.apply_calibration cal t in
        Printf.sprintf "visual=%b boot=%d shift=%d ingame=%d"
          t.visual_shiny_check t.boot_offset_ms t.seed_shift t.ingame_offset
    | Error c -> Pokemon_engine.Failure.cause_to_string c
  in
  [
    case "phase1 catch_mode with visual shiny check"
      (decode_mode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "frame_model": "switch",
            "catch_mode": "phase1", "visual_shiny_check": true,
            "ball": "luxury-ball"}|})
      "policy(ball=luxury-ball,wall=true) visual=true boot=0 shift=0 ingame=0";
    case "phase2 catch_mode has no wall"
      (decode_mode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "frame_model": "switch",
            "catch_mode": "phase2", "ball": "ultra-ball"}|})
      "policy(ball=ultra-ball,wall=false) visual=false boot=0 shift=0 ingame=0";
    case "invalid catch_mode rejected"
      (decode_mode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "frame_model": "switch",
            "catch_mode": "master_only"}|})
      "bad_args: wild_rng: catch_mode is master_only, not throw_only, phase1, \
       or phase2";
    case "apply_calibration updates switch plan offsets" decode_calibrated
      "visual=true boot=-50 shift=4 ingame=-2";
    case "--options overrides catch_mode, attempts, ball, and balls"
      (fun () ->
        let options =
          options_of
            [
              ("tid", "1");
              ("sid", "2");
              ("ball", "luxury-ball");
              ("balls", "30");
              ("catch_mode", "phase1");
              ("attempts", "10");
            ]
        in
        match Wild_rng_plan.decode ~options (obj plan_args_no_ids) with
        | Ok t ->
            let mode =
              match t.catch_mode with
              | Throw_only -> "throw_only"
              | Catch_policy { policy; _ } ->
                  Printf.sprintf "policy(ball=%s,max_balls=%d)" policy.ball_name
                    policy.max_balls
            in
            Printf.sprintf "%s attempts=%d" mode t.capture.max_encounters
        | Error c -> Pokemon_engine.Failure.cause_to_string c)
      "policy(ball=luxury-ball,max_balls=30) attempts=10";
    case "apply_timing_delta shifts seed_delay_ms by exact ms"
      (fun () ->
        let base =
          Result.get_ok
            (Wild_rng_plan.decode
               (obj
                  {|{"species": "ekans", "location": "route_10", "tid": 12345,
                     "sid": 54321, "frame_model": "switch"}|}))
        in
        let t0 = Result.get_ok (Wild_rng_plan.target base) in
        let shifted =
          Wild_rng_plan.apply_timing_delta ~boot_delta_ms:(-8) ~ingame_delta:0
            base
        in
        let t1 = Result.get_ok (Wild_rng_plan.target shifted) in
        Printf.sprintf "delta_ms=%d"
          (t1.timings.seed_delay_ms - t0.timings.seed_delay_ms))
      "delta_ms=-8";
  ]

let policy_decisions =
  [
    case "visual shiny hit -> catch -> summary star confirmed"
      (decide_policy ~intro_verdict:Shiny ~catch_outcome:(Caught caught_summary)
         ~shiny:true ~party:5)
      "find, intro shiny, catch_battle, finish_catch, summary 6 => passes \
       (balls=2)";
    case "visual non-shiny miss skips catch & throws 0 balls, runs on_miss"
      (decide_policy ~intro_verdict:Not_shiny
         ~catch_outcome:(Caught caught_summary) ~shiny:true ~party:5)
      "find, intro not_shiny, on_miss => wild_rng_not_shiny_intro (balls=none)";
    case "visual unknown still catches and checks summary star guard"
      (decide_policy ~intro_verdict:Unknown
         ~catch_outcome:(Caught caught_summary) ~shiny:false ~party:5)
      "find, intro unknown, catch_battle, finish_catch, summary 6 => \
       wild_rng_not_shiny (balls=2)";
    case "policy catch without visual check catches and checks summary"
      (decide_policy ~catch_outcome:(Caught caught_summary) ~shiny:true ~party:4)
      "find, catch_battle, finish_catch, summary 5 => passes (balls=2)";
    case "catch runner pause stops cleanly without summary"
      (decide_policy ~intro_verdict:Shiny
         ~catch_outcome:
           (Paused { reason = "max turns reached"; summary = caught_summary })
         ~shiny:true ~party:5)
      "find, intro shiny, catch_battle => wild_rng_catch_paused (balls=none)";
    case "catch runner no_balls maps to out_of_balls"
      (decide_policy ~intro_verdict:Shiny
         ~catch_outcome:(No_balls caught_summary) ~shiny:true ~party:5)
      "find, intro shiny, catch_battle => wild_rng_out_of_balls (balls=none)";
    case "no encounter fails before intro check"
      (decide_policy ~found:false ~intro_verdict:Shiny
         ~catch_outcome:(Caught caught_summary) ~shiny:true ~party:5)
      "find => wild_rng_no_encounter (balls=none)";
    case "multi-attempt retries after non-shiny miss and succeeds on attempt 2"
      (fun () ->
        let attempt = ref 0 in
        let steps = ref [] in
        let add s = steps := s :: !steps in
        let pc : Wild_rng.policy_catch_steps =
          {
            find_encounter =
              (fun () ->
                incr attempt;
                add (Printf.sprintf "find#%d" !attempt);
                true);
            detect_shiny = None;
            on_miss = ignore;
            catch_battle =
              (fun () ->
                add (Printf.sprintf "catch#%d" !attempt);
                Caught caught_summary);
            finish_catch = (fun _ -> true);
          }
        in
        let game_steps : Wild_rng.game_steps =
          {
            catch = (fun _ ~party:_ -> failwith "unused");
            policy_catch = Some pc;
            shiny_at =
              (fun _ ->
                let ok = !attempt = 2 in
                add (Printf.sprintf "summary#%d=%b" !attempt ok);
                ok);
            log = ignore;
          }
        in
        let base = Result.get_ok (Wild_rng_plan.decode (obj plan_args)) in
        let plan = { base.capture with max_encounters = 3 } in
        let r = Wild_rng.run game_steps plan ~party:5 in
        Printf.sprintf "%s => %s"
          (String.concat ", " (List.rev !steps))
          (Option.value (Wild_rng.failure_code r.end_) ~default:"passes"))
      "find#1, catch#1, summary#1=false, find#2, catch#2, summary#2=true => \
       passes";
  ]

let decisions =
  [
    case "a shiny catch passes"
      (decide ~capture_end:All_caught ~shiny:true ~party:5)
      "catch (party 5), summary 6: passes";
    case "a catch without the star fails"
      (decide ~capture_end:All_caught ~shiny:false ~party:4)
      "catch (party 4), summary 5: wild_rng_not_shiny";
    case "another species: out of attempts, no summary"
      (decide ~capture_end:Out_of_encounters ~shiny:true ~party:5)
      "catch (party 5): wild_rng_out_of_encounters";
    case "a full party fails before the reset"
      (decide ~capture_end:All_caught ~shiny:true ~party:6)
      ": wild_rng_party_full";
  ]

let method_decoding =
  let decode_method json () =
    match Wild_rng_plan.decode (obj json) with
    | Ok t ->
        Printf.sprintf "%s at %s (%s, %s, %s)" t.species t.location
          (Wild_rng_plan.encounter_method_to_string t.encounter_method)
          t.seeds t.frame_model
    | Error c -> Pokemon_engine.Failure.cause_to_string c
  in
  let super_rod_blind () =
    Wild_rng_steps.blind_presses_for Wild_rng_plan.Super_rod
      {
        seed_delay_ms = 33033;
        csf_delay_ms = 3348;
        teachy_delay_ms = 0;
        ingame_delay_ms = 10129;
      }
    |> List.map command_text |> String.concat ", "
  in
  let check_surf_target () =
    let args =
      obj
        {|{"method": "surf", "species": "psyduck", "location": "viridian_city",
           "tid": 12345, "sid": 54321}|}
    in
    match
      Result.bind (Wild_rng_plan.decode args) (fun p ->
          Result.map_error
            (Pokemon_engine.Failure.cause "target")
            (Wild_rng_plan.target p))
    with
    | Ok t -> t.encounter.species
    | Error c -> Pokemon_engine.Failure.cause_to_string c
  in
  let check_super_rod_target () =
    let args =
      obj
        {|{"method": "super_rod", "species": "shellder",
           "location": "vermilion_city", "tid": 12345, "sid": 54321}|}
    in
    match
      Result.bind (Wild_rng_plan.decode args) (fun p ->
          Result.map_error
            (Pokemon_engine.Failure.cause "target")
            (Wild_rng_plan.target p))
    with
    | Ok t -> t.encounter.species
    | Error c -> Pokemon_engine.Failure.cause_to_string c
  in
  [
    case "surf method with default seeds and frame_model"
      (decode_method
         {|{"method": "surf", "species": "psyduck",
            "location": "viridian_city", "tid": 1, "sid": 2}|})
      "psyduck at viridian_city (surf, rng_seeds_mgba_sevii_save.json, mgba)";
    case "super_rod method with default seeds and frame_model"
      (decode_method
         {|{"method": "super_rod", "species": "shellder",
            "location": "vermilion_city", "tid": 1, "sid": 2}|})
      "shellder at vermilion_city (super_rod, rng_seeds_mgba_sevii_save.json, \
       mgba)";
    case "invalid method rejected"
      (decode_method
         {|{"method": "old_rod", "species": "magikarp",
            "location": "vermilion_city", "tid": 1, "sid": 2}|})
      "bad_args: wild_rng: method is old_rod, not grass, surf, or super_rod";
    case "super_rod blind presses cast registered rod with Select"
      super_rod_blind
      "wait 33033, A 3000/0, wait 348, A 50/1450, B 50/2450, wait 9629, Select \
       200/300";
    case "surf target search finds shiny psyduck in viridian_city"
      check_surf_target "psyduck";
    case "super_rod target search finds shiny shellder in vermilion_city"
      check_super_rod_target "shellder";
  ]

let () =
  Table_test.run "wild_rng"
    (decoding @ policy_decoding @ method_decoding @ presses @ decisions
   @ policy_decisions)
