module M = Menu_input
module T = Frlg_rng.Rng_timings
module P = Wild_rng_plan
module WT = Frlg_rng.Wild_target
module Cal = Rng_calibrated_steps

(* The fork's press lengths (ms). *)
let seed_hold_ms = 3000
let tap_ms = 50
let continue_release_ms = 1450
let recap_release_ms = 2450
let menu_hold_ms = 200
let menu_release_ms = 300
let party_open_ms = 1000
let sweet_scent_release_ms = 800
let super_rod_fixed_duration_ms = 500
let bite_timeout_ms = 12000
let battle_timeout_ms = 20000
let hold = M.hold

(* set_seed_after_delay and load_game_after_delay. *)
let title_presses (t : T.t) =
  [
    Wire.Wait { wait_ms = t.seed_delay_ms };
    hold ~hold_ms:seed_hold_ms ~cooldown_ms:0 Wire.A;
    Wire.Wait { wait_ms = t.csf_delay_ms - seed_hold_ms };
    hold ~hold_ms:tap_ms ~cooldown_ms:continue_release_ms Wire.A;
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

let game_steps ~log ?show_counters ?reset_mode ?encounter_method t plan =
  Cal.capture_steps ~log ?show_counters
    ~find_encounter:(find_encounter ~log ?reset_mode ?encounter_method t)
    plan

let legacy_catch = Cal.legacy_catch
let policy_catch_for = Cal.policy_catch_for

let policy_catch_steps ~log ?reset_mode ?encounter_method ~timings
    ?(visual_shiny_check = false) ?(on_miss = fun ~party:_ -> ()) ~config
    ~policy () =
  Cal.make_policy_catch ~log
    ~find_encounter:(find_encounter ~log ?reset_mode ?encounter_method timings)
    ~visual_shiny_check ~on_miss ~config ~policy

let check_summary = Cal.check_summary
let shiny_at ~log ~slot = check_summary ~log ~slot ~read_miss:false = `Shiny

let rng_target_of_wild (tgt : WT.t) : Cal.rng_target =
  {
    seed = tgt.seed;
    table_delay_ms = tgt.table_delay_ms;
    advance = tgt.advance;
    timings = tgt.timings;
    description = WT.describe tgt;
  }

let calibrate_wild_miss ~log (plan : P.t) ~is_switch ~label
    ~(target : Cal.rng_target) ~calibrator ~used_boot_offset_ms
    ~used_ingame_offset (miss : Rng_miss_calibration.summary_miss) =
  let species = Option.value ~default:plan.species miss.species in
  match P.slots plan with
  | Error e ->
      log (label ^ " miss search skipped: " ^ e);
      None
  | Ok slots ->
      let super_rod = plan.encounter_method = P.Super_rod in
      Rng_miss_calibration.report_and_calibrate_wild_rolling ~log ~label
        ~species ~slots ~super_rod ~seeds:plan.seeds ~seed_shift:plan.seed_shift
        ~target_seed:target.seed ~target_delay_ms:target.table_delay_ms
        ~target_advance:target.advance ~persist:is_switch ~calibrator
        ~used_boot_offset_ms ~used_ingame_offset miss.observation

let live_calibrated_game_steps ~log ?(reset_mode = Rng_reset.Mgba) (plan : P.t)
    (tgt : WT.t) : Wild_rng.game_steps =
  let is_switch = plan.frame_model = "switch" in
  let find_target ~boot_offset_ms ~ingame_offset ~exclude_targets =
    let p = { plan with boot_offset_ms; ingame_offset } in
    Result.map rng_target_of_wild (P.target ~exclude_targets p)
  in
  Cal.make ~log
    {
      prefix = "Wild RNG";
      is_switch;
      total_attempts = plan.capture.max_encounters;
      cal_ball_row = plan.cal_ball_row;
      capture = plan.capture;
      catch_mode = plan.catch_mode;
      visual_shiny_check = plan.visual_shiny_check;
      initial_boot_offset_ms = plan.boot_offset_ms;
      initial_ingame_offset = plan.ingame_offset;
      initial_target = rng_target_of_wild tgt;
      find_target;
      find_encounter =
        find_encounter ~log ~reset_mode ~encounter_method:plan.encounter_method;
      calibrate_miss = calibrate_wild_miss ~log plan ~is_switch;
    }
