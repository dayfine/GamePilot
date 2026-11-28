module P = Wild_rng_plan
module WT = Frlg_rng.Wild_target
module RC = Frlg_rng.Rolling_calibrator

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

let calibrated_policy_catch ~log ~reset_mode ~find_encounter ~policy_catch_steps
    ~timings ~prepare ~on_miss (plan : P.t) =
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
    Some { base with Wild_rng.find_encounter }
  in
  match (plan.catch_mode, plan.visual_shiny_check) with
  | P.Throw_only, false -> None
  | P.Throw_only, true ->
      make ~visual_shiny_check:true ~config:P.default_catch_config
        ~policy:(P.throw_only_policy plan.capture)
  | P.Catch_policy { policy; config }, visual_shiny_check ->
      make ~visual_shiny_check ~config ~policy

let calibrated_catch ~log ~reset_mode ~game_steps ~encounter_method ~prepare
    capture ~party =
  match prepare () with
  | Error e ->
      { Capture.end_ = Failed e; encounters = 0; balls_thrown = 0; caught = [] }
  | Ok (tgt : WT.t) ->
      let steps =
        game_steps ~log ~reset_mode ~encounter_method tgt.timings capture
      in
      Effects.with_probes Frlg_battle.Battle_look.probes (fun () ->
          Capture.run steps capture ~party)

let calibrated_shiny_at ~log ~check_summary st slot =
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

let make ~log ?(reset_mode = Rng_reset.Mgba) ~find_encounter ~game_steps
    ~policy_catch_steps ~check_summary (plan : P.t) (tgt : WT.t) :
    Wild_rng.game_steps =
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
  and shiny_at = calibrated_shiny_at ~log ~check_summary st in
  let on_miss =
    if st.is_switch then fast_calibration_on_miss ~log st ~shiny_at
    else fun ~party:_ -> ()
  in
  {
    catch =
      calibrated_catch ~log ~reset_mode ~game_steps
        ~encounter_method:plan.encounter_method ~prepare;
    policy_catch =
      calibrated_policy_catch ~log ~reset_mode ~find_encounter
        ~policy_catch_steps ~timings:tgt.timings ~prepare ~on_miss plan;
    shiny_at;
    log;
    show_counters = Watch_report.counters;
  }
