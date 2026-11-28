module Opts = Static_rng_options
module R = Bdsp_readers.Shiny_encounter_reader
module Trigger = Bdsp_blink_rng.Static_rng_trigger
module E = Bdsp_rng.Static_encounter

type outcome =
  | Shiny_found of { attempt : int; hit : E.hit; reading : R.reading }
  | Exhausted of { attempts : int; last_reason : string }

type countdown = { remaining_ms : int; until_ms : int }
type time_units = { ms_per_s : int; secs_per_min : int; secs_per_hour : int }

let time_units = { ms_per_s = 1000; secs_per_min = 60; secs_per_hour = 3600 }

let format_countdown_ms ms =
  let total_s = max 0 ((ms + time_units.ms_per_s - 1) / time_units.ms_per_s) in
  let h = total_s / time_units.secs_per_hour in
  let m = total_s mod time_units.secs_per_hour / time_units.secs_per_min in
  let s = total_s mod time_units.secs_per_min in
  if h > 0 then Printf.sprintf "%d:%02d:%02d" h m s
  else Printf.sprintf "%d:%02d" m s

let format_target (hit : E.hit) =
  Printf.sprintf "%s %s"
    (E.shiny_name hit.pokemon.shiny)
    (E.nature_name hit.pokemon.nature)

let watch_counters ~attempt ~max_attempts ~phase ?target ?countdown () =
  let countdown_item { remaining_ms; until_ms } =
    Wire.Watch.counter ~until_ms "Countdown" (format_countdown_ms remaining_ms)
  in
  List.filter_map Fun.id
    [
      Some
        (Wire.Watch.counter "Attempt"
           (Printf.sprintf "%d/%d" attempt max_attempts));
      Some (Wire.Watch.counter "Phase" phase);
      Option.map (Wire.Watch.counter "Target") target;
      Option.map countdown_item countdown;
    ]

type game_steps = {
  log : string -> unit;
  show_counters : Wire.Watch.counter list -> unit;
  freeze_player : unit -> unit;
  recover_pedestal_seed :
    timeout_s:int -> (Pedestal_seed_finder.outcome, string) result;
  enter_chamber : unit -> (unit, string) result;
  reidentify_in_chamber :
    base_state:Bdsp_rng.Xorshift128.state ->
    (Bdsp_blink_rng.In_chamber_reidentifier.anchor, string) result;
  trigger_encounter :
    on_phase:
      (phase:string -> ?target:string -> ?countdown:countdown -> unit -> unit) ->
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

let log_phase ~steps ~attempt ~(opts : Opts.t) ?target ?countdown phase msg =
  steps.show_counters
    (watch_counters ~attempt ~max_attempts:opts.max_attempts ~phase ?target
       ?countdown ());
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
  log_phase ~steps ~attempt ~opts "Enter chamber" msg;
  let* () = steps.enter_chamber () in
  log_phase ~steps ~attempt ~opts "1PK anchor"
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
  log_phase ~steps ~attempt ~opts "Seed locked" msg;
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
  log_phase ~steps ~attempt ~opts "0PK seed"
    "Freezing player and recovering 128-bit seed from player eye blinks...";
  let res =
    let* anchor = acquire_anchor ~steps ~attempt ~opts in
    let on_phase ~phase ?target ?countdown () =
      steps.show_counters
        (watch_counters ~attempt ~max_attempts:opts.max_attempts ~phase ?target
           ?countdown ())
    in
    steps.log
      (Printf.sprintf
         "[attempt %d/%d] Anchor locked at adv=%d (tick=%.4fs, \
          pk_phase=[%.2f..%.2f]s). Scheduling %s encounter..."
         attempt opts.max_attempts anchor.advances_to_last_blink
         anchor.fitted_tick_seconds anchor.next_pokemon_blink_min_seconds
         anchor.next_pokemon_blink_max_seconds opts.target.template.species);
    let* trig =
      steps.trigger_encounter ~on_phase (trigger_config_of_options opts) anchor
    in
    let jitter_ms = trig.batch_done.t_ms -. trig.plan.confirm_t_ms in
    log_phase ~steps ~attempt ~opts
      ~target:(format_target trig.plan.hit)
      "Triggering"
      (Printf.sprintf
         "Triggered adv=%d (start=%d confirm=%.3fs margin=%.2fs jitter=%+.0fms \
          span=%d ev=%d, %s, %s, IVs %s). Watching battle intro..."
         trig.plan.hit.advances trig.plan.timeline_start_advance
         trig.plan.schedule.confirm_seconds
         trig.plan.schedule.gap_margin_seconds jitter_ms trig.plan.schedule.span
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
    log_phase ~steps ~attempt ~opts "Soft reset"
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
        log_phase ~steps ~attempt ~opts ~target:(format_target hit)
          "Shiny found"
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
