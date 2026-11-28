module M = Menu_input
module T = Frlg_rng.Rng_timings
module P = Wild_rng_plan
module WT = Frlg_rng.Wild_target
module RC = Frlg_rng.Rolling_calibrator

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
let star_timeout_ms = 1000
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

let game_steps ~log ?reset_mode ?encounter_method t plan =
  let spot = ref (Pacing.on_patch None) in
  {
    (Capture_steps.make ~log ~spot plan) with
    find_encounter = find_encounter ~log ?reset_mode ?encounter_method t;
    flee = (fun () -> true);
  }

let policy_catch_steps ~log ?reset_mode ?encounter_method ~timings
    ?(visual_shiny_check = false) ?(on_miss = fun ~party:_ -> ()) ~config
    ~policy () : Wild_rng.policy_catch_steps =
  let detect_shiny =
    if visual_shiny_check then
      Some (fun () -> Frlg_readers.Shiny_encounter_detector.detect ())
    else None
  in
  {
    find_encounter = find_encounter ~log ?reset_mode ?encounter_method timings;
    detect_shiny;
    on_miss;
    catch_battle =
      (fun () ->
        Pokemon_catch.Catch_runner.run ~log
          (Battle_catch_steps.make ~log config)
          policy);
    finish_catch = Capture_steps.finish_catch ~log;
  }

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

type live_state = {
  plan : P.t ref;
  target : WT.t ref;
  calibrator : RC.t ref;
  excluded : (int * int) list ref;
  attempt : int ref;
  is_switch : bool;
  label : unit -> string;
}

let next_wild_target st =
  incr st.attempt;
  if !(st.attempt) = 1 then Ok !(st.target)
  else P.target ~exclude_targets:!(st.excluded) !(st.plan)

let prepare_target ~log st () =
  match next_wild_target st with
  | Error e ->
      log (st.label () ^ ": failed to recompute target: " ^ e);
      Error e
  | Ok tgt ->
      st.target := tgt;
      log (st.label () ^ ": " ^ WT.describe tgt ^ ".");
      Ok tgt

let skip_parity_locked ~log st (tgt : WT.t) next_cal =
  log
    (Printf.sprintf
       "%s: parity lock detected on seed %04X advance %d — skipping target and \
        resetting advance history."
       (st.label ()) tgt.seed tgt.advance);
  st.excluded := (tgt.seed, tgt.advance) :: !(st.excluded);
  st.calibrator := RC.reset next_cal

let with_estimate (p : P.t) (e : RC.estimate) =
  { p with boot_offset_ms = e.boot_offset_ms; ingame_offset = e.ingame_offset }

let apply_rolling_update ~log st (p : P.t) tgt (next_cal, est) =
  st.plan := with_estimate p est;
  if st.is_switch && RC.parity_locked next_cal then
    skip_parity_locked ~log st tgt next_cal
  else st.calibrator := next_cal

let calibrate_miss ~log st (miss : Rng_miss_calibration.summary_miss) =
  let p = !(st.plan) and tgt = !(st.target) and label = st.label () in
  let species = Option.value ~default:p.species miss.species in
  match P.slots p with
  | Error e -> log (label ^ " miss search skipped: " ^ e)
  | Ok slots ->
      let super_rod = p.encounter_method = P.Super_rod in
      Rng_miss_calibration.report_and_calibrate_wild_rolling ~log ~label
        ~species ~slots ~super_rod ~seeds:p.seeds ~seed_shift:p.seed_shift
        ~target_seed:tgt.seed ~target_delay_ms:tgt.table_delay_ms
        ~target_advance:tgt.advance ~persist:st.is_switch
        ~calibrator:!(st.calibrator) ~used_boot_offset_ms:p.boot_offset_ms
        ~used_ingame_offset:p.ingame_offset miss.observation
      |> Option.iter (apply_rolling_update ~log st p tgt)

let calibrated_policy_catch ~log ~reset_mode ~timings ~prepare ~on_miss
    (plan : P.t) =
  let encounter_method = plan.encounter_method in
  let find_encounter () =
    match prepare () with
    | Error _ -> false
    | Ok (tgt : WT.t) ->
        find_encounter ~log ~reset_mode ~encounter_method tgt.timings ()
  in
  let make ~visual_shiny_check ~config ~policy =
    let base =
      policy_catch_steps ~log ~reset_mode ~encounter_method ~timings
        ~visual_shiny_check ~on_miss ~config ~policy ()
    in
    Some { base with find_encounter }
  in
  match (plan.catch_mode, plan.visual_shiny_check) with
  | P.Throw_only, false -> None
  | P.Throw_only, true ->
      make ~visual_shiny_check:true ~config:P.default_catch_config
        ~policy:(P.throw_only_policy plan.capture)
  | P.Catch_policy { policy; config }, visual_shiny_check ->
      make ~visual_shiny_check ~config ~policy

let calibrated_catch ~log ~reset_mode ~encounter_method ~prepare capture ~party
    =
  match prepare () with
  | Error e ->
      { Capture.end_ = Failed e; encounters = 0; balls_thrown = 0; caught = [] }
  | Ok (tgt : WT.t) ->
      let steps =
        game_steps ~log ~reset_mode ~encounter_method tgt.timings capture
      in
      Effects.with_probes Frlg_battle.Battle_look.probes (fun () ->
          Capture.run steps capture ~party)

let calibrated_shiny_at ~log st slot =
  match check_summary ~log ~slot ~read_miss:st.is_switch with
  | `Shiny -> true
  | `Not_shiny None -> false
  | `Not_shiny (Some miss) ->
      calibrate_miss ~log st miss;
      false

(* Fast throw-only catch on a visual Not_shiny miss (throws cal_ball_row in the
   Poké Balls pocket on Turn 1), then reads Summary to calibrate the next try. *)
let fast_calibration_on_miss ~log st ~shiny_at ~party =
  log (st.label () ^ ": visual miss — fast throw-only catch for calibration.");
  let p = !(st.plan) in
  let bag = { Battle_catch_steps.ball_row = p.cal_ball_row; heal_row = 0 } in
  let steps =
    Battle_catch_steps.make ~log { P.default_catch_config with bag }
  in
  match
    Pokemon_catch.Catch_runner.run ~log steps (P.throw_only_policy p.capture)
  with
  | Pokemon_catch.Catch_runner.Caught _ ->
      if Capture_steps.finish_catch ~log Party then
        ignore (shiny_at (party + 1) : bool)
      else log (st.label () ^ ": calibration catch did not return to overworld.")
  | _ -> log (st.label () ^ ": fast calibration catch ended without catching.")

let live_calibrated_game_steps ~log ?(reset_mode = Rng_reset.Mgba) (plan : P.t)
    (tgt : WT.t) : Wild_rng.game_steps =
  let attempt = ref 0 and total = max 1 plan.capture.max_encounters in
  let st =
    {
      plan = ref plan;
      target = ref tgt;
      calibrator = ref RC.empty;
      excluded = ref [];
      attempt;
      is_switch = plan.frame_model = "switch";
      label =
        (fun () -> Printf.sprintf "Wild RNG (attempt %d/%d)" !attempt total);
    }
  in
  let prepare = prepare_target ~log st
  and shiny_at = calibrated_shiny_at ~log st in
  let on_miss =
    if st.is_switch then fast_calibration_on_miss ~log st ~shiny_at
    else fun ~party:_ -> ()
  in
  {
    catch =
      calibrated_catch ~log ~reset_mode ~encounter_method:plan.encounter_method
        ~prepare;
    policy_catch =
      calibrated_policy_catch ~log ~reset_mode ~timings:tgt.timings ~prepare
        ~on_miss plan;
    shiny_at;
    log;
  }
