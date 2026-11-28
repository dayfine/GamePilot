module M = Menu_input
module T = Frlg_rng.Rng_timings
module P = Wild_rng_plan

(* The fork's press lengths (ms). *)
let seed_hold_ms = 3000
let tap_ms = 50
let recap_release_ms = 2450
let menu_hold_ms = 200
let menu_release_ms = 300
let party_open_ms = 1000
let sweet_scent_release_ms = 800
let super_rod_fixed_duration_ms = 500
let bite_timeout_ms = 12000
let battle_timeout_ms = 20000
let star_timeout_ms = 1000
let hold = M.hold

(* set_seed_after_delay and load_game_after_delay. *)
let title_presses (t : T.t) =
  [
    Wire.Wait { wait_ms = t.seed_delay_ms };
    hold ~hold_ms:seed_hold_ms ~cooldown_ms:0 Wire.A;
    Wire.Wait { wait_ms = t.csf_delay_ms - seed_hold_ms };
    hold ~hold_ms:tap_ms ~cooldown_ms:t.recap_delay_ms Wire.A;
    hold ~hold_ms:tap_ms ~cooldown_ms:recap_release_ms Wire.B;
  ]

(* use_sweet_scent: the last party slot's menu, Sweet Scent after the wait. *)
let sweet_scent_presses (t : T.t) =
  let menu = hold ~hold_ms:menu_hold_ms ~cooldown_ms:menu_release_ms in
  [
    menu Wire.Start;
    menu Wire.Down;
    hold ~hold_ms:menu_hold_ms ~cooldown_ms:party_open_ms Wire.A;
    menu Wire.Up;
    menu Wire.Up;
    menu Wire.A;
    hold ~hold_ms:menu_hold_ms
      ~cooldown_ms:(t.ingame_delay_ms - T.sweet_scent_fixed_duration_ms)
      Wire.Down;
    hold ~hold_ms:menu_hold_ms ~cooldown_ms:sweet_scent_release_ms Wire.A;
  ]

let blind_presses t = title_presses t @ sweet_scent_presses t

(* Registered Super Rod on Select, cast after the in-game wait. *)
let super_rod_presses (t : T.t) =
  let wait_ms = max 0 (t.ingame_delay_ms - super_rod_fixed_duration_ms) in
  title_presses t
  @ [
      Wire.Wait { wait_ms };
      hold ~hold_ms:menu_hold_ms ~cooldown_ms:menu_release_ms Wire.Select;
    ]

let blind_presses_for (m : Wild_rng_plan.encounter_method) t =
  match m with
  | Grass | Surf -> blind_presses t
  | Super_rod -> super_rod_presses t

let confirm_bite ~log () =
  let wait () =
    Effects.await ~timeout_ms:bite_timeout_ms Frlg_readers.Dialog.dialog_up
  in
  match Effects.with_probes Frlg_readers.Dialog.probes wait with
  | Holds _ ->
      log "Wild RNG: fishing bite dialog shown, pressing A.";
      M.press Wire.A;
      true
  | Timeout ->
      log "Wild RNG: timed out waiting for fishing bite.";
      false

let find_encounter ~log ?(reset_mode = Rng_reset.Mgba)
    ?(encounter_method = P.Grass) t () =
  log
    (Printf.sprintf "Wild RNG (%s): resetting for blind presses."
       (P.encounter_method_to_string encounter_method));
  Rng_reset.reset_and_submit ~log reset_mode
    (blind_presses_for encounter_method t);
  let bite_ok = encounter_method <> P.Super_rod || confirm_bite ~log () in
  bite_ok
  &&
  match
    Effects.await ~timeout_ms:battle_timeout_ms
      Frlg_readers.Battle_screen.battle_shows
  with
  | Holds _ -> true
  | Timeout -> false

let capture_steps ~log ?(show_counters = ignore) ~find_encounter
    (plan : Capture_plan.t) =
  let spot = ref (Pacing.on_patch None) in
  let base = Capture_steps.make ~log ~spot plan in
  let total = plan.max_encounters in
  let attempt = ref 0 in
  let report phase =
    show_counters
      (Wild_rng.watch_counters ~attempt:(max 1 !attempt) ~total ~phase)
  in
  {
    base with
    find_encounter =
      (fun () ->
        incr attempt;
        report "reset";
        find_encounter ());
    read_encounter =
      (fun () ->
        report "encounter";
        base.read_encounter ());
    throw_ball =
      (fun () ->
        report "catch";
        base.throw_ball ());
    flee = (fun () -> true);
  }

let game_steps ~log ?reset_mode ?show_counters ?encounter_method t plan =
  capture_steps ~log ?show_counters
    ~find_encounter:(find_encounter ~log ?reset_mode ?encounter_method t)
    plan

let legacy_catch ~log ?show_counters ~find_encounter capture ~party =
  Effects.with_probes Frlg_battle.Battle_look.probes (fun () ->
      Capture.run
        (capture_steps ~log ?show_counters ~find_encounter capture)
        capture ~party)

let make_policy_catch ~log ~find_encounter ~visual_shiny_check ~on_miss ~config
    ~policy : Wild_rng.policy_catch_steps =
  let detect_shiny =
    if visual_shiny_check then
      Some (fun () -> Frlg_readers.Shiny_encounter_detector.detect ())
    else None
  in
  {
    find_encounter;
    detect_shiny;
    on_miss;
    catch_battle =
      (fun () ->
        Pokemon_catch.Catch_runner.run ~log
          (Battle_catch_steps.make ~log config)
          policy);
    finish_catch = Capture_steps.finish_catch ~log;
  }

let policy_catch_for ~log ~find_encounter ?(on_miss = ignore) ~catch_mode
    ~visual_shiny_check capture =
  let mk =
    make_policy_catch ~log ~find_encounter ~on_miss:(fun ~party:_ -> on_miss ())
  in
  match (catch_mode, visual_shiny_check) with
  | Wild_rng_plan.Throw_only, false -> None
  | Wild_rng_plan.Throw_only, true ->
      Some
        (mk ~visual_shiny_check:true ~config:Wild_rng_plan.default_catch_config
           ~policy:(Wild_rng_plan.throw_only_policy capture))
  | Wild_rng_plan.Catch_policy { policy; config }, visual_shiny_check ->
      Some (mk ~visual_shiny_check ~config ~policy)

let policy_catch_steps ~log ?reset_mode ?encounter_method ~timings
    ?(visual_shiny_check = false) ?(on_miss = fun ~party:_ -> ()) ~config
    ~policy () =
  make_policy_catch ~log
    ~find_encounter:(find_encounter ~log ?reset_mode ?encounter_method timings)
    ~visual_shiny_check ~on_miss ~config ~policy

let check_open_summary ~log ~slot ~read_miss () =
  Summary_moves.open_summary slot;
  let shiny =
    match
      Effects.await ~timeout_ms:star_timeout_ms Frlg_readers.Shiny_star.shiny
    with
    | Holds _ -> true
    | Timeout -> false
  in
  log
    (Printf.sprintf "Wild RNG: slot %d's summary %s the shiny star." slot
       (if shiny then "shows" else "does not show"));
  let result =
    if shiny then `Shiny
    else if read_miss then
      `Not_shiny (Rng_miss_calibration.read_summary_miss ())
    else `Not_shiny None
  in
  M.close_to_overworld ~label:"summary" ~log;
  result

let check_summary ~log ~slot ~read_miss =
  Effects.with_probes
    (Frlg_readers.Summary_screen.probes @ Frlg_readers.Shiny_star.probes)
    (check_open_summary ~log ~slot ~read_miss)

let shiny_at ~log ~slot = check_summary ~log ~slot ~read_miss:false = `Shiny

let calibrated_find ~log ~reset_mode ~encounter_method =
  find_encounter ~log ~reset_mode ~encounter_method

let calibrated_game_steps ~log ~reset_mode ~encounter_method t plan =
  game_steps ~log ~reset_mode ~show_counters:Watch_report.counters
    ~encounter_method t plan

let calibrated_policy ~log ~reset_mode ~encounter_method ~timings
    ~visual_shiny_check ~on_miss ~config ~policy =
  policy_catch_steps ~log ~reset_mode ~encounter_method ~timings
    ~visual_shiny_check ~on_miss ~config ~policy

let live_calibrated_game_steps ~log ?reset_mode plan tgt =
  Wild_rng_calibrated_steps.make ~log ?reset_mode
    ~find_encounter:calibrated_find ~game_steps:calibrated_game_steps
    ~policy_catch_steps:calibrated_policy ~check_summary plan tgt
