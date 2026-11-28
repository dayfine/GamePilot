module M = Menu_input
module T = Frlg_rng.Rng_timings
module P = Wild_rng_plan
module RC = Frlg_rng.Rolling_calibrator

let star_timeout_ms = 1000

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

let policy_catch_for ~log ~find_encounter ?(on_miss = fun ~party:_ -> ())
    ~catch_mode ~visual_shiny_check capture =
  let mk = make_policy_catch ~log ~find_encounter ~on_miss in
  match (catch_mode, visual_shiny_check) with
  | P.Throw_only, false -> None
  | P.Throw_only, true ->
      Some
        (mk ~visual_shiny_check:true ~config:P.default_catch_config
           ~policy:(P.throw_only_policy capture))
  | P.Catch_policy { policy; config }, visual_shiny_check ->
      Some (mk ~visual_shiny_check ~config ~policy)

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

type rng_target = {
  seed : int;
  table_delay_ms : int;
  advance : int;
  timings : T.t;
  description : string;
}

type spec = {
  prefix : string;
  is_switch : bool;
  total_attempts : int;
  cal_ball_row : int;
  capture : Capture_plan.t;
  catch_mode : P.catch_mode;
  visual_shiny_check : bool;
  initial_boot_offset_ms : int;
  initial_ingame_offset : int;
  initial_target : rng_target;
  find_target :
    boot_offset_ms:int ->
    ingame_offset:int ->
    exclude_targets:(int * int) list ->
    (rng_target, string) result;
  find_encounter : T.t -> unit -> bool;
  calibrate_miss :
    label:string ->
    target:rng_target ->
    calibrator:RC.t ->
    used_boot_offset_ms:int ->
    used_ingame_offset:int ->
    Rng_miss_calibration.summary_miss ->
    (RC.t * RC.estimate) option;
}

type live_state = {
  spec : spec;
  boot_offset_ms : int ref;
  ingame_offset : int ref;
  target : rng_target ref;
  calibrator : RC.t ref;
  excluded : (int * int) list ref;
  attempt : int ref;
  label : unit -> string;
}

let next_target st =
  incr st.attempt;
  if !(st.attempt) = 1 then Ok !(st.target)
  else
    st.spec.find_target ~boot_offset_ms:!(st.boot_offset_ms)
      ~ingame_offset:!(st.ingame_offset) ~exclude_targets:!(st.excluded)

let prepare_target ~log st () =
  match next_target st with
  | Error e ->
      log (st.label () ^ ": failed to recompute target: " ^ e);
      Error e
  | Ok tgt ->
      st.target := tgt;
      log (st.label () ^ ": " ^ tgt.description ^ ".");
      Ok tgt

let skip_parity_locked ~log st (tgt : rng_target) next_cal =
  log
    (Printf.sprintf
       "%s: parity lock detected on seed %04X advance %d — skipping target and \
        resetting advance history."
       (st.label ()) tgt.seed tgt.advance);
  st.excluded := (tgt.seed, tgt.advance) :: !(st.excluded);
  st.calibrator := RC.reset next_cal

let apply_rolling_update ~log st tgt (next_cal, (est : RC.estimate)) =
  st.boot_offset_ms := est.boot_offset_ms;
  st.ingame_offset := est.ingame_offset;
  if st.spec.is_switch && RC.parity_locked next_cal then
    skip_parity_locked ~log st tgt next_cal
  else st.calibrator := next_cal

let calibrated_shiny_at ~log st slot =
  match check_summary ~log ~slot ~read_miss:st.spec.is_switch with
  | `Shiny -> true
  | `Not_shiny None -> false
  | `Not_shiny (Some miss) ->
      let tgt = !(st.target) in
      st.spec.calibrate_miss ~label:(st.label ()) ~target:tgt
        ~calibrator:!(st.calibrator) ~used_boot_offset_ms:!(st.boot_offset_ms)
        ~used_ingame_offset:!(st.ingame_offset) miss
      |> Option.iter (apply_rolling_update ~log st tgt);
      false

(* Fast throw-only catch on a visual Not_shiny miss (throws cal_ball_row in the
   Poké Balls pocket on Turn 1), then reads Summary to calibrate the next try. *)
let fast_calibration_on_miss ~log st ~shiny_at ~party =
  log (st.label () ^ ": visual miss — fast throw-only catch for calibration.");
  let bag =
    { Battle_catch_steps.ball_row = st.spec.cal_ball_row; heal_row = 0 }
  in
  let steps =
    Battle_catch_steps.make ~log { P.default_catch_config with bag }
  in
  match
    Pokemon_catch.Catch_runner.run ~log steps
      (P.throw_only_policy st.spec.capture)
  with
  | Pokemon_catch.Catch_runner.Caught _ ->
      if Capture_steps.finish_catch ~log Party then
        ignore (shiny_at (party + 1) : bool)
      else log (st.label () ^ ": calibration catch did not return to overworld.")
  | _ -> log (st.label () ^ ": fast calibration catch ended without catching.")

let calibrated_catch ~log ~show_counters ~find_encounter ~prepare capture ~party
    =
  match prepare () with
  | Error e ->
      { Capture.end_ = Failed e; encounters = 0; balls_thrown = 0; caught = [] }
  | Ok (tgt : rng_target) ->
      legacy_catch ~log ~show_counters
        ~find_encounter:(find_encounter tgt.timings)
        capture ~party

let make ~log ?(show_counters = Watch_report.counters) (spec : spec) :
    Wild_rng.game_steps =
  let attempt = ref 0 and total = max 1 spec.total_attempts in
  let st =
    {
      spec;
      boot_offset_ms = ref spec.initial_boot_offset_ms;
      ingame_offset = ref spec.initial_ingame_offset;
      target = ref spec.initial_target;
      calibrator = ref RC.empty;
      excluded = ref [];
      attempt;
      label =
        (fun () ->
          Printf.sprintf "%s (attempt %d/%d)" spec.prefix !attempt total);
    }
  in
  let prepare = prepare_target ~log st in
  let shiny_at = calibrated_shiny_at ~log st in
  let on_miss =
    if spec.is_switch then fast_calibration_on_miss ~log st ~shiny_at
    else fun ~party:_ -> ()
  in
  let find_encounter () =
    match prepare () with
    | Error _ -> false
    | Ok tgt -> spec.find_encounter tgt.timings ()
  in
  {
    catch =
      calibrated_catch ~log ~show_counters ~find_encounter:spec.find_encounter
        ~prepare;
    policy_catch =
      policy_catch_for ~log ~find_encounter ~on_miss ~catch_mode:spec.catch_mode
        ~visual_shiny_check:spec.visual_shiny_check spec.capture;
    shiny_at;
    log;
    show_counters;
  }
