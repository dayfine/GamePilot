(* Scripted Workflow B unit tests for Bdsp_static_rng.

   The fake game_steps record stands in for the live Switch console: it returns
   synthetic boot seeds, in-chamber anchors, trigger outcomes, and shiny battle
   readings while recording every phase transition and soft-reset call. *)

open Bdsp_static_rng
module Opts = Static_rng_options
module WF = Static_rng_workflow
module E = Bdsp_rng.Static_encounter
module R = Bdsp_readers.Shiny_encounter_reader
module X = Bdsp_rng.Xorshift128

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let check_eq label ~expected ~actual = if expected <> actual then fail label

let dummy_state : X.state =
  { s0 = 0x12345678; s1 = 0x9abcdef0; s2 = 0x13579bdf; s3 = 0x2468ace0 }

let dummy_seed : Bdsp_blink_rng.Munchlax_seed_finder.outcome =
  {
    state = dummy_state;
    solve =
      {
        success = true;
        state = dummy_state;
        advances_to_last_interval = 40;
        observations_used = 40;
        observations_discarded = 0;
        equations_used = 128;
        null_space_dimension = 0;
        attempts = 1;
        weakest_margin_used = 0.2;
        mistimed_intervals = 0;
        worst_residual_seconds = 0.01;
        failure_reason = "";
      };
    blink_count = 46;
    gaps = [];
    threshold = 0.25;
    elapsed_seconds = 120.0;
  }

let dummy_anchor : Bdsp_blink_rng.In_chamber_reidentifier.anchor =
  {
    base_state = dummy_state;
    anchor_time_ms = 50_000.0;
    advances_to_first_blink = 100;
    advances_to_last_blink = 120;
    next_pokemon_blink_min_seconds = 3.0;
    next_pokemon_blink_max_seconds = 5.0;
    fitted_tick_seconds = 1.018;
    gaps = [];
  }

let dummy_hit ~shiny : E.hit =
  {
    advances = 250;
    state = dummy_state;
    pokemon =
      {
        ec = 1;
        pid = 2;
        shiny;
        ivs =
          {
            hp = 31;
            attack = 0;
            defense = 31;
            spatk = 31;
            spdef = 31;
            speed = 31;
          };
        ability = 0;
        gender = Genderless;
        nature = 15;
        level = 70;
        height = 128;
        weight = 128;
      };
  }

let dummy_trigger_outcome ~shiny : Bdsp_blink_rng.Static_rng_trigger.outcome =
  let hit = dummy_hit ~shiny in
  {
    plan =
      {
        hit;
        timeline_start_advance = 130;
        schedule =
          {
            span = 120;
            confirm_seconds = 5.2;
            events_before_confirm = 36;
            gap_margin_seconds = 0.5;
          };
        open_t_ms = 55_000.0;
        confirm_t_ms = 60_200.0;
      };
    batch_done = { batch_id = "b1"; seq = 1; t_ms = 60_250.0 };
  }

let shiny_reading : R.reading =
  {
    verdict = R.Shiny;
    wild_animation_ms = Some 3900.;
    your_animation_ms = Some 1800.;
    phase = R.Post_entry;
  }

let non_shiny_reading : R.reading =
  {
    verdict = R.Not_shiny;
    wild_animation_ms = Some 1850.;
    your_animation_ms = Some 1800.;
    phase = R.Post_entry;
  }

let make_fake_steps ~readings ~resets ~captured_delay_ms ~captured_sync () :
    WF.game_steps =
  let queue = ref readings in
  {
    log = (fun _ -> ());
    update_counters = (fun ~attempt:_ ~max_attempts:_ ~phase:_ -> ());
    recover_boot_seed = (fun ~timeout_s:_ -> Ok dummy_seed);
    enter_save = (fun () -> Ok ());
    reidentify_in_chamber = (fun ~base_state:_ -> Ok dummy_anchor);
    trigger_encounter =
      (fun cfg _anchor ->
        captured_delay_ms := Some cfg.aim_offset_ms;
        captured_sync := cfg.search.synchronize_nature;
        Ok (dummy_trigger_outcome ~shiny:E.Star));
    detect_shiny =
      (fun () ->
        match !queue with
        | [] -> non_shiny_reading
        | hd :: tl ->
            queue := tl;
            hd);
    soft_reset =
      (fun () ->
        incr resets;
        Ok ());
  }

let default_opts () =
  match Opts.of_run_options Run_options.none with
  | Ok opts -> opts
  | Error e -> fail ("default options failed: " ^ e)

let test_shiny_hit_attempt_one () =
  let resets = ref 0 in
  let delay = ref None in
  let sync = ref None in
  let opts = { (default_opts ()) with delay_ms = 250; sync_nature = Some 15 } in
  let steps =
    make_fake_steps ~readings:[ shiny_reading ] ~resets ~captured_delay_ms:delay
      ~captured_sync:sync ()
  in
  let outcome = WF.run ~steps opts in
  let expected =
    WF.Shiny_found
      { attempt = 1; hit = dummy_hit ~shiny:E.Star; reading = shiny_reading }
  in
  check_eq "shiny found on attempt 1" ~expected ~actual:outcome;
  check_eq "no soft reset after shiny hit" ~expected:0 ~actual:!resets;
  check_eq "delay_ms forwarded" ~expected:(Some 250.0) ~actual:!delay;
  check_eq "sync nature forwarded" ~expected:(Some 15) ~actual:!sync

let test_retry_then_shiny_attempt_two () =
  let resets = ref 0 in
  let delay = ref None in
  let sync = ref None in
  let opts = { (default_opts ()) with max_attempts = 3 } in
  let steps =
    make_fake_steps
      ~readings:[ non_shiny_reading; shiny_reading ]
      ~resets ~captured_delay_ms:delay ~captured_sync:sync ()
  in
  let outcome = WF.run ~steps opts in
  let expected =
    WF.Shiny_found
      { attempt = 2; hit = dummy_hit ~shiny:E.Star; reading = shiny_reading }
  in
  check_eq "shiny found on attempt 2" ~expected ~actual:outcome;
  check_eq "exactly one soft reset before attempt 2" ~expected:1 ~actual:!resets

let test_exhausted_max_attempts () =
  let resets = ref 0 in
  let delay = ref None in
  let sync = ref None in
  let opts = { (default_opts ()) with max_attempts = 2 } in
  let steps =
    make_fake_steps
      ~readings:[ non_shiny_reading; non_shiny_reading ]
      ~resets ~captured_delay_ms:delay ~captured_sync:sync ()
  in
  let outcome = WF.run ~steps opts in
  let expected =
    WF.Exhausted
      {
        attempts = 2;
        last_reason =
          "battle detector: verdict=not_shiny wild=1850ms your=1800ms";
      }
  in
  check_eq "exhausted after 2 attempts" ~expected ~actual:outcome;
  check_eq "one soft reset between attempts 1 and 2" ~expected:1 ~actual:!resets

let test_invalid_options_rejected () =
  let decls : Run_options.declared list =
    [
      {
        key = "target";
        value = Run_options.Text;
        presence = Run_options.Optional;
        doc = "target";
      };
      {
        key = "shiny";
        value = Run_options.Text;
        presence = Run_options.Optional;
        doc = "shiny";
      };
      {
        key = "sync";
        value = Run_options.Text;
        presence = Run_options.Optional;
        doc = "sync";
      };
    ]
  in
  let check_err label pairs =
    match Run_options.check decls pairs with
    | Error e -> fail ("unexpected Run_options error: " ^ e)
    | Ok ro -> (
        match Opts.of_run_options ro with
        | Ok _ -> fail ("expected error for " ^ label)
        | Error _ -> ())
  in
  check_err "unknown target" [ ("target", "mew") ];
  check_err "unknown shiny filter" [ ("shiny", "ultra") ];
  check_err "unknown sync nature" [ ("sync", "sleepy") ]

let () =
  test_shiny_hit_attempt_one ();
  test_retry_then_shiny_attempt_two ();
  test_exhausted_max_attempts ();
  test_invalid_options_rejected ();
  print_endline "OK"
