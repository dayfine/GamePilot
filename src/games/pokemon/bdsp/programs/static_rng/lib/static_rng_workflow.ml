module Opts = Static_rng_options
module R = Bdsp_readers.Shiny_encounter_reader
module Trigger = Bdsp_blink_rng.Static_rng_trigger
module E = Bdsp_rng.Static_encounter

type outcome =
  | Shiny_found of { attempt : int; hit : E.hit; reading : R.reading }
  | Exhausted of { attempts : int; last_reason : string }

type game_steps = {
  log : string -> unit;
  update_counters : attempt:int -> max_attempts:int -> phase:string -> unit;
  freeze_player : unit -> unit;
  recover_pedestal_seed :
    timeout_s:int -> (Pedestal_seed_finder.outcome, string) result;
  enter_chamber : unit -> (unit, string) result;
  reidentify_in_chamber :
    base_state:Bdsp_rng.Xorshift128.state ->
    (Bdsp_blink_rng.In_chamber_reidentifier.anchor, string) result;
  trigger_encounter :
    Trigger.config ->
    Bdsp_blink_rng.In_chamber_reidentifier.anchor ->
    (Trigger.outcome, string) result;
  detect_shiny : unit -> R.reading;
  soft_reset_to_pedestal : unit -> (unit, string) result;
}

type attempt_result = Hit of E.hit * R.reading | Retry of string

let trigger_config_of_options (opts : Opts.t) =
  let base =
    Trigger.default_config ~target:opts.target
      ~accept:(Opts.accept_pokemon opts.shiny)
  in
  { base with aim_offset_ms = float_of_int opts.delay_ms }

let log_phase ~steps ~attempt ~(opts : Opts.t) phase msg =
  steps.update_counters ~attempt ~max_attempts:opts.max_attempts ~phase;
  steps.log (Printf.sprintf "[attempt %d/%d] %s" attempt opts.max_attempts msg)

let ( let* ) = Result.bind

type precheck_window = { min_advances : int; max_advances : int }

let precheck_cfg = { min_advances = 400; max_advances = 3500 }

let check_seed_early_hit ~(opts : Opts.t) state =
  let searcher =
    E.searcher state opts.target.template ~tsv:0 ~synchronize_nature:None
  in
  match
    E.scan searcher ~min_advances:precheck_cfg.min_advances
      ~max_advances:precheck_cfg.max_advances
      ~accept:(Opts.accept_pokemon opts.shiny)
  with
  | hit :: _ -> Ok hit
  | [] ->
      Error
        (Printf.sprintf
           "no matching shiny in adv=[%d..%d] (pre-chamber seed check)"
           precheck_cfg.min_advances precheck_cfg.max_advances)

let anchor_of_seed (seed : Pedestal_seed_finder.outcome) :
    Bdsp_blink_rng.In_chamber_reidentifier.anchor =
  {
    base_state = seed.state;
    anchor_time_ms = seed.anchor_time_ms;
    advances_to_first_blink = 0;
    advances_to_last_blink = seed.anchor_advance;
    next_pokemon_blink_min_seconds = 0.0;
    next_pokemon_blink_max_seconds = 0.0;
    fitted_tick_seconds = seed.tick_seconds;
    gaps = [];
  }

let enter_and_reidentify ~steps ~attempt ~opts ~seed_hex
    (seed : Pedestal_seed_finder.outcome) (preview : E.hit) =
  let msg =
    Printf.sprintf
      "Seed confirmed %s (%d blinks, %.1fs, tick=%.4fs; earliest hit adv=%d). \
       Inserting slate..."
      seed_hex seed.events seed.elapsed_seconds seed.tick_seconds
      preview.advances
  in
  log_phase ~steps ~attempt ~opts "enter_chamber" msg;
  let* () = steps.enter_chamber () in
  log_phase ~steps ~attempt ~opts "reidentify_1pk"
    "Re-identifying in-chamber 1PK advance anchor...";
  steps.reidentify_in_chamber ~base_state:seed.state

let lock_in_place ~steps ~attempt ~opts ~seed_hex
    (seed : Pedestal_seed_finder.outcome) (preview : E.hit) =
  let msg =
    Printf.sprintf
      "Seed confirmed in place %s (%d blinks, %.1fs, tick=%.4fs; earliest hit \
       adv=%d)."
      seed_hex seed.events seed.elapsed_seconds seed.tick_seconds
      preview.advances
  in
  log_phase ~steps ~attempt ~opts "seed_locked" msg;
  Ok (anchor_of_seed seed)

let acquire_anchor ~steps ~attempt ~(opts : Opts.t) =
  steps.freeze_player ();
  let* seed = steps.recover_pedestal_seed ~timeout_s:opts.seed_timeout_s in
  let* preview = check_seed_early_hit ~opts seed.state in
  let seed_hex = Bdsp_rng.Xorshift128.state_to_string seed.state in
  match opts.target.entry_mode with
  | Bdsp_rng.Static_targets.Ramanas_slate_chamber ->
      enter_and_reidentify ~steps ~attempt ~opts ~seed_hex seed preview
  | Bdsp_rng.Static_targets.Standing_at_encounter ->
      lock_in_place ~steps ~attempt ~opts ~seed_hex seed preview

let run_attempt ~steps ~attempt ~(opts : Opts.t) =
  log_phase ~steps ~attempt ~opts "pedestal_seed"
    "Freezing player and recovering 128-bit seed from player eye blinks...";
  let res =
    let* anchor = acquire_anchor ~steps ~attempt ~opts in
    log_phase ~steps ~attempt ~opts "trigger"
      (Printf.sprintf "Anchor locked at adv=%d. Scheduling %s encounter..."
         anchor.advances_to_last_blink opts.target.template.species);
    let* trig =
      steps.trigger_encounter (trigger_config_of_options opts) anchor
    in
    log_phase ~steps ~attempt ~opts "detect_shiny"
      (Printf.sprintf
         "Triggered adv=%d (start=%d confirm=%.3fs span=%d ev=%d, %s, %s, IVs \
          %s). Watching battle intro..."
         trig.plan.hit.advances trig.plan.timeline_start_advance
         trig.plan.schedule.confirm_seconds trig.plan.schedule.span
         trig.plan.schedule.events_before_confirm
         (E.shiny_name trig.plan.hit.pokemon.shiny)
         (E.nature_name trig.plan.hit.pokemon.nature)
         (E.ivs_to_string trig.plan.hit.pokemon.ivs));
    Ok (trig.plan.hit, steps.detect_shiny ())
  in
  match res with
  | Error e -> Retry e
  | Ok (hit, reading) -> (
      match reading.verdict with
      | R.Shiny -> Hit (hit, reading)
      | R.Not_shiny | R.Unknown ->
          Retry ("battle detector: " ^ R.format_reading reading))

let retry_after_miss ~steps ~attempt ~(opts : Opts.t) ~reason next =
  steps.log
    (Printf.sprintf "[attempt %d/%d] miss: %s" attempt opts.max_attempts reason);
  if attempt >= opts.max_attempts then
    Exhausted { attempts = attempt; last_reason = reason }
  else (
    log_phase ~steps ~attempt ~opts "soft_reset"
      "Soft-resetting via Switch HOME back to empty pedestal...";
    match steps.soft_reset_to_pedestal () with
    | Ok () -> next (attempt + 1)
    | Error e ->
        Exhausted
          { attempts = attempt; last_reason = "soft reset failed: " ^ e })

let run ~steps (opts : Opts.t) =
  steps.log ("Starting bdsp.static_rng: " ^ Opts.format_summary opts);
  let rec loop attempt =
    match run_attempt ~steps ~attempt ~opts with
    | Hit (hit, reading) ->
        log_phase ~steps ~attempt ~opts "shiny_found"
          ("SHINY CONFIRMED! " ^ R.format_reading reading
         ^ " — parked on battle screen ready for capture.");
        Shiny_found { attempt; hit; reading }
    | Retry reason -> retry_after_miss ~steps ~attempt ~opts ~reason loop
  in
  loop 1

let format_found (opts : Opts.t) attempt (hit : E.hit) reading =
  Printf.sprintf "bdsp.static_rng: SHINY %s on attempt %d/%d (adv=%d, %s, %s)"
    opts.target.template.species attempt opts.max_attempts hit.advances
    (E.nature_name hit.pokemon.nature)
    (R.format_reading reading)

let format_exhausted (opts : Opts.t) attempts last_reason =
  Printf.sprintf "bdsp.static_rng: no shiny %s after %d attempt(s) (%s)"
    opts.target.template.species attempts last_reason

let outcome_to_result (opts : Opts.t) = function
  | Shiny_found { attempt; hit; reading } ->
      (true, format_found opts attempt hit reading)
  | Exhausted { attempts; last_reason } ->
      (false, format_exhausted opts attempts last_reason)
