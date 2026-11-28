(* Scripted Workflow A unit tests for Bdsp_static_rng.

   The fake game_steps record stands in for the live Switch console: it returns
   synthetic pedestal seeds, in-chamber anchors, trigger outcomes, and shiny
   battle readings while recording every phase transition and soft-reset call. *)

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

let dummy_seed : Pedestal_seed_finder.outcome =
  {
    state = dummy_state;
    events = 45;
    anchor_time_ms = 40_000.0;
    anchor_advance = 45;
    tick_seconds = 1.0198;
    elapsed_seconds = 250.0;
  }

let dummy_anchor : Bdsp_blink_rng.In_chamber_reidentifier.anchor =
  {
    base_state = dummy_state;
    anchor_time_ms = 50_000.0;
    advances_to_first_blink = 575;
    advances_to_last_blink = 650;
    next_pokemon_blink_min_seconds = 0.0;
    next_pokemon_blink_max_seconds = 0.42;
    fitted_tick_seconds = 1.015;
    gaps = [];
  }

let dummy_hit ~shiny : E.hit =
  {
    advances = 780;
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
        timeline_start_advance = 660;
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
    wild_animation_ms = Some 544.;
    your_animation_ms = Some 1800.;
    phase = R.Post_entry;
  }

let make_fake_steps ~readings ~resets ~captured_delay_ms () : WF.game_steps =
  let queue = ref readings in
  {
    log = (fun _ -> ());
    show_counters = (fun _ -> ());
    freeze_player = (fun () -> ());
    recover_pedestal_seed = (fun ~timeout_s:_ -> Ok dummy_seed);
    enter_chamber = (fun () -> Ok ());
    reidentify_in_chamber = (fun ~base_state:_ -> Ok dummy_anchor);
    trigger_encounter =
      (fun ~on_phase:_ cfg _anchor ->
        captured_delay_ms := Some cfg.aim_offset_ms;
        Ok (dummy_trigger_outcome ~shiny:E.Star));
    detect_shiny =
      (fun () ->
        match !queue with
        | [] -> non_shiny_reading
        | hd :: tl ->
            queue := tl;
            hd);
    soft_reset_to_pedestal =
      (fun () ->
        incr resets;
        Ok ());
  }

let default_opts () =
  match Opts.of_run_options Run_options.none with
  | Ok opts -> { opts with shiny = Opts.Include_non_shiny }
  | Error e -> fail ("default options failed: " ^ e)

let test_precheck_skips_chamber_when_no_early_shiny () =
  let resets = ref 0 in
  let entered = ref 0 in
  let delay = ref None in
  let opts = { (default_opts ()) with shiny = Opts.Square; max_attempts = 1 } in
  let base =
    make_fake_steps ~readings:[ shiny_reading ] ~resets ~captured_delay_ms:delay
      ()
  in
  let empty_seed =
    { dummy_seed with state = { s0 = 1; s1 = 1; s2 = 1; s3 = 1 } }
  in
  let steps =
    {
      base with
      recover_pedestal_seed = (fun ~timeout_s:_ -> Ok empty_seed);
      enter_chamber =
        (fun () ->
          incr entered;
          Ok ());
    }
  in
  let outcome = WF.run ~steps opts in
  check_eq "chamber never entered on seed with no early shiny" ~expected:0
    ~actual:!entered;
  match outcome with
  | WF.Exhausted { attempts = 1; _ } -> ()
  | _ -> fail "expected pre-chamber rejection to exhaust after 1 attempt"

let string_contains ~sub s =
  let sub_len = String.length sub in
  let s_len = String.length s in
  let rec loop i =
    if i + sub_len > s_len then false
    else if String.sub s i sub_len = sub then true
    else loop (i + 1)
  in
  loop 0

let test_shiny_hit_attempt_one () =
  let resets = ref 0 in
  let delay = ref None in
  let logs = ref [] in
  let opts = { (default_opts ()) with delay_ms = 250 } in
  let base =
    make_fake_steps ~readings:[ shiny_reading ] ~resets ~captured_delay_ms:delay
      ()
  in
  let steps = { base with log = (fun line -> logs := line :: !logs) } in
  let outcome = WF.run ~steps opts in
  let expected =
    WF.Shiny_found
      { attempt = 1; hit = dummy_hit ~shiny:E.Star; reading = shiny_reading }
  in
  check_eq "shiny found on attempt 1" ~expected ~actual:outcome;
  check_eq "no soft reset after shiny hit" ~expected:0 ~actual:!resets;
  check_eq "delay_ms forwarded" ~expected:(Some 250.0) ~actual:!delay;
  let all_logs = String.concat "\n" (List.rev !logs) in
  check_eq "logs pk_phase on anchor lock" ~expected:true
    ~actual:(string_contains ~sub:"pk_phase=[0.00..0.42]s" all_logs);
  check_eq "logs margin on trigger" ~expected:true
    ~actual:(string_contains ~sub:"margin=0.50s" all_logs);
  check_eq "logs jitter on trigger" ~expected:true
    ~actual:(string_contains ~sub:"jitter=+50ms" all_logs)

let test_standing_at_encounter_skips_chamber () =
  let resets = ref 0 in
  let entered = ref 0 in
  let reidentified = ref 0 in
  let delay = ref None in
  let dialga = Option.get (Bdsp_rng.Static_targets.find "dialga") in
  let opts = { (default_opts ()) with target = dialga } in
  let base =
    make_fake_steps ~readings:[ shiny_reading ] ~resets ~captured_delay_ms:delay
      ()
  in
  let steps =
    {
      base with
      enter_chamber =
        (fun () ->
          incr entered;
          Ok ());
      reidentify_in_chamber =
        (fun ~base_state:_ ->
          incr reidentified;
          Ok dummy_anchor);
    }
  in
  let outcome = WF.run ~steps opts in
  let expected =
    WF.Shiny_found
      { attempt = 1; hit = dummy_hit ~shiny:E.Star; reading = shiny_reading }
  in
  check_eq "standing target found shiny on attempt 1" ~expected ~actual:outcome;
  check_eq "standing target skips enter_chamber" ~expected:0 ~actual:!entered;
  check_eq "standing target skips reidentify_in_chamber" ~expected:0
    ~actual:!reidentified

let test_retry_then_shiny_attempt_two () =
  let resets = ref 0 in
  let delay = ref None in
  let opts = { (default_opts ()) with max_attempts = 3 } in
  let steps =
    make_fake_steps
      ~readings:[ non_shiny_reading; shiny_reading ]
      ~resets ~captured_delay_ms:delay ()
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
  let opts = { (default_opts ()) with max_attempts = 2 } in
  let steps =
    make_fake_steps
      ~readings:[ non_shiny_reading; non_shiny_reading ]
      ~resets ~captured_delay_ms:delay ()
  in
  let outcome = WF.run ~steps opts in
  let expected =
    WF.Exhausted
      {
        attempts = 2;
        last_reason =
          "battle detector: verdict=not_shiny wild=544ms your=1800ms";
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
  check_err "legacy shiny=all rejected" [ ("shiny", "all") ];
  match Run_options.check decls [ ("shiny", "include_non_shiny") ] with
  | Error e -> fail ("unexpected Run_options error: " ^ e)
  | Ok ro -> (
      match Opts.of_run_options ro with
      | Ok cfg ->
          check_eq "shiny=include_non_shiny decoded"
            ~expected:Opts.Include_non_shiny ~actual:cfg.shiny
      | Error e -> fail ("expected include_non_shiny to succeed: " ^ e))

let test_watch_counters_and_countdown () =
  check_eq "countdown 0ms" ~expected:"0:00" ~actual:(WF.format_countdown_ms 0);
  check_eq "countdown negative clamped" ~expected:"0:00"
    ~actual:(WF.format_countdown_ms (-500));
  check_eq "countdown rounds up partial second" ~expected:"0:01"
    ~actual:(WF.format_countdown_ms 500);
  check_eq "countdown minutes" ~expected:"24:15"
    ~actual:(WF.format_countdown_ms 1_455_000);
  check_eq "countdown hours" ~expected:"1:01:05"
    ~actual:(WF.format_countdown_ms 3_665_000);
  let target = WF.format_target (dummy_hit ~shiny:E.Star) in
  check_eq "format_target" ~expected:"Star Shiny Modest" ~actual:target;
  let resets = ref 0 in
  let delay = ref None in
  let history = ref [] in
  let opts = { (default_opts ()) with max_attempts = 5 } in
  let base =
    make_fake_steps ~readings:[ shiny_reading ] ~resets ~captured_delay_ms:delay
      ()
  in
  let until_ms = 1_800_000_060_000 in
  let steps =
    {
      base with
      show_counters = (fun items -> history := items :: !history);
      trigger_encounter =
        (fun ~on_phase cfg anchor ->
          on_phase ~phase:"Waiting (adv=780)" ~target
            ~countdown:{ remaining_ms = 60_000; until_ms }
            ();
          on_phase ~phase:"Final 1PK re-anchor" ~target ();
          on_phase ~phase:"Triggering" ~target ();
          base.trigger_encounter ~on_phase cfg anchor);
    }
  in
  ignore (WF.run ~steps opts : WF.outcome);
  let updates = List.rev !history in
  let phase_of items =
    items
    |> List.find_opt (fun (c : Wire.Watch.counter) -> c.label = "Phase")
    |> Option.map (fun (c : Wire.Watch.counter) -> c.value)
  in
  let countdown_of items =
    items
    |> List.find_opt (fun (c : Wire.Watch.counter) -> c.label = "Countdown")
    |> Option.map (fun (c : Wire.Watch.counter) -> (c.value, c.until_ms))
  in
  check_eq "emitted phases in order"
    ~expected:
      [
        Some "0PK seed";
        Some "Enter chamber";
        Some "1PK anchor";
        Some "Waiting (adv=780)";
        Some "Final 1PK re-anchor";
        Some "Triggering";
        Some "Triggering";
        Some "Shiny found";
      ]
    ~actual:(List.map phase_of updates);
  check_eq "countdown set during Waiting and cleared on re-anchor/trigger"
    ~expected:
      [ None; None; None; Some ("1:00", Some until_ms); None; None; None; None ]
    ~actual:(List.map countdown_of updates)

let () =
  test_shiny_hit_attempt_one ();
  test_standing_at_encounter_skips_chamber ();
  test_retry_then_shiny_attempt_two ();
  test_exhausted_max_attempts ();
  test_precheck_skips_chamber_when_no_early_shiny ();
  test_invalid_options_rejected ();
  test_watch_counters_and_countdown ();
  print_endline "OK"
