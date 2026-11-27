module M = Menu_input
module T = Frlg_rng.Rng_timings

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

let await_bite ~log () =
  match
    Effects.await ~timeout_ms:bite_timeout_ms Frlg_readers.Dialog.dialog_up
  with
  | Holds _ ->
      log "Wild RNG: fishing bite dialog shown, pressing A.";
      M.press Wire.A;
      true
  | Timeout ->
      log "Wild RNG: timed out waiting for fishing bite.";
      false

let confirm_bite ~log () =
  Effects.with_probes Frlg_readers.Dialog.probes (await_bite ~log)

let find_encounter ~log ?(reset_mode = Rng_reset.Mgba)
    ?(encounter_method = Wild_rng_plan.Grass) t () =
  log
    (Printf.sprintf "Wild RNG (%s): resetting for blind presses."
       (Wild_rng_plan.encounter_method_to_string encounter_method));
  Rng_reset.reset_and_submit ~log reset_mode
    (blind_presses_for encounter_method t);
  let bite_ok =
    match encounter_method with
    | Super_rod -> confirm_bite ~log ()
    | Grass | Surf -> true
  in
  if not bite_ok then false
  else
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
    ?(visual_shiny_check = false) ?(on_miss = ignore) ~config ~policy () :
    Wild_rng.policy_catch_steps =
  let detect_shiny =
    if visual_shiny_check then
      Some (fun () -> Frlg_readers.Shiny_encounter_detector.detect ())
    else None
  in
  let catch_battle () =
    Pokemon_catch.Catch_runner.run ~log
      (Battle_catch_steps.make ~log config)
      policy
  in
  {
    find_encounter = find_encounter ~log ?reset_mode ?encounter_method timings;
    detect_shiny;
    on_miss;
    catch_battle;
    finish_catch = Capture_steps.finish_catch ~log;
  }

let read_star () =
  match
    Effects.await ~timeout_ms:star_timeout_ms Frlg_readers.Shiny_star.shiny
  with
  | Holds _ -> true
  | Timeout -> false

let skills_page = 2

let miss_gender_of = function
  | Some Frlg_text.Summary_stats.Male -> Frlg_rng.Rng_miss_search.Male
  | Some Female -> Female
  | Some Genderless -> Genderless
  | None -> Unknown

let miss_stats_of (s : Frlg_text.Summary_stats.stats) :
    Frlg_rng.Rng_miss_search.stats =
  { hp = s.hp; atk = s.atk; def = s.def; spa = s.spa; spd = s.spd; spe = s.spe }

let read_page2_stats glyphs =
  Summary_paging.to_page skills_page;
  Summary_paging.settled (fun () -> Frlg_text.Summary_stats.read_stats glyphs)
  |> Option.map miss_stats_of

let read_miss_observation () =
  let glyphs = Text_data.glyphs () in
  let level =
    Summary_paging.settled (fun () -> Frlg_text.Summary_stats.read_level glyphs)
  in
  Option.map
    (fun level ->
      let nature = Frlg_text.Summary_stats.read_nature glyphs in
      let gender = miss_gender_of (Frlg_text.Summary_stats.read_gender ()) in
      let stats = read_page2_stats glyphs in
      { Frlg_rng.Rng_miss_search.nature; gender; level; stats })
    level

let check_open_summary ~log ~slot ~read_miss () =
  Summary_moves.open_summary slot;
  let shiny = read_star () in
  log
    (Printf.sprintf "Wild RNG: slot %d's summary %s the shiny star." slot
       (if shiny then "shows" else "does not show"));
  let result =
    if shiny then `Shiny
    else if read_miss then `Not_shiny (read_miss_observation ())
    else `Not_shiny None
  in
  M.close_to_overworld ~label:"summary" ~log;
  result

let check_summary ~log ~slot ~read_miss =
  Effects.with_probes
    (Frlg_readers.Summary_screen.probes @ Frlg_readers.Shiny_star.probes)
    (check_open_summary ~log ~slot ~read_miss)

let shiny_at ~log ~slot =
  match check_summary ~log ~slot ~read_miss:false with
  | `Shiny -> true
  | `Not_shiny _ -> false

let next_wild_target ~first_attempt ~current_plan ~current_target =
  if !first_attempt then (
    first_attempt := false;
    Ok !current_target)
  else Wild_rng_plan.target !current_plan

let prepare_target ~log ~first_attempt ~current_plan ~current_target () =
  match next_wild_target ~first_attempt ~current_plan ~current_target with
  | Error e ->
      log ("Wild RNG: failed to recompute target: " ^ e);
      Error e
  | Ok tgt ->
      current_target := tgt;
      log ("Wild RNG: " ^ Frlg_rng.Wild_target.describe tgt ^ ".");
      Ok tgt

let calibrate_miss ~log ~is_switch ~current_plan ~prev_seed_delta
    ~(tgt : Frlg_rng.Wild_target.t) obs =
  let (p : Wild_rng_plan.t) = !current_plan in
  match
    Rng_miss_calibration.report_and_calibrate ~log ~label:"Wild RNG"
      ~species:p.species ~seeds:p.seeds ~seed_shift:p.seed_shift
      ~target_seed:tgt.seed ~target_delay_ms:tgt.table_delay_ms
      ~target_advance:tgt.advance ~persist:is_switch
      ?prev_seed_delta:!prev_seed_delta obs
  with
  | None -> ()
  | Some d ->
      prev_seed_delta := Some d.seed_delta_frames;
      current_plan :=
        Wild_rng_plan.apply_timing_delta ~boot_delta_ms:d.boot_delta_ms
          ~ingame_delta:d.ingame_delta p

let calibrated_find ~log ~reset_mode ~encounter_method ~prepare () =
  match prepare () with
  | Error _ -> false
  | Ok (tgt : Frlg_rng.Wild_target.t) ->
      find_encounter ~log ~reset_mode ~encounter_method tgt.timings ()

let make_calibrated_policy ~log ~reset_mode ~encounter_method ~timings ~prepare
    ~visual_shiny_check ~config ~policy =
  let base =
    policy_catch_steps ~log ~reset_mode ~encounter_method ~timings
      ~visual_shiny_check ~config ~policy ()
  in
  let find_encounter =
    calibrated_find ~log ~reset_mode ~encounter_method ~prepare
  in
  Some { base with find_encounter }

let calibrated_policy_catch ~log ~reset_mode ~timings ~prepare
    (plan : Wild_rng_plan.t) =
  let encounter_method = plan.encounter_method in
  match (plan.catch_mode, plan.visual_shiny_check) with
  | Wild_rng_plan.Throw_only, false -> None
  | Wild_rng_plan.Throw_only, true ->
      make_calibrated_policy ~log ~reset_mode ~encounter_method ~timings
        ~prepare ~visual_shiny_check:true
        ~config:Wild_rng_plan.default_catch_config
        ~policy:(Wild_rng_plan.throw_only_policy plan.capture)
  | Wild_rng_plan.Catch_policy { policy; config }, visual_shiny_check ->
      make_calibrated_policy ~log ~reset_mode ~encounter_method ~timings
        ~prepare ~visual_shiny_check ~config ~policy

let calibrated_catch ~log ~reset_mode ~encounter_method ~prepare capture ~party
    =
  match prepare () with
  | Error e ->
      { Capture.end_ = Failed e; encounters = 0; balls_thrown = 0; caught = [] }
  | Ok (tgt : Frlg_rng.Wild_target.t) ->
      let steps =
        game_steps ~log ~reset_mode ~encounter_method tgt.timings capture
      in
      Effects.with_probes Frlg_battle.Battle_look.probes (fun () ->
          Capture.run steps capture ~party)

let calibrated_shiny_at ~log ~is_switch ~current_plan ~prev_seed_delta
    ~current_target slot =
  match check_summary ~log ~slot ~read_miss:is_switch with
  | `Shiny -> true
  | `Not_shiny None -> false
  | `Not_shiny (Some obs) ->
      calibrate_miss ~log ~is_switch ~current_plan ~prev_seed_delta
        ~tgt:!current_target obs;
      false

let live_calibrated_game_steps ~log ?(reset_mode = Rng_reset.Mgba)
    (initial_plan : Wild_rng_plan.t) (initial_target : Frlg_rng.Wild_target.t) :
    Wild_rng.game_steps =
  let current_plan = ref initial_plan in
  let current_target = ref initial_target in
  let prev_seed_delta = ref None in
  let first_attempt = ref true in
  let is_switch = initial_plan.frame_model = "switch" in
  let prepare =
    prepare_target ~log ~first_attempt ~current_plan ~current_target
  in
  {
    catch =
      calibrated_catch ~log ~reset_mode
        ~encounter_method:initial_plan.encounter_method ~prepare;
    policy_catch =
      calibrated_policy_catch ~log ~reset_mode ~timings:initial_target.timings
        ~prepare initial_plan;
    shiny_at =
      calibrated_shiny_at ~log ~is_switch ~current_plan ~prev_seed_delta
        ~current_target;
    log;
  }
