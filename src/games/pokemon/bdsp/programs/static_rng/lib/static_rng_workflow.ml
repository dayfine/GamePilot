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
  recover_boot_seed :
    timeout_s:int ->
    (Bdsp_blink_rng.Munchlax_seed_finder.outcome, string) result;
  enter_save : unit -> (unit, string) result;
  reidentify_in_chamber :
    base_state:Bdsp_rng.Xorshift128.state ->
    (Bdsp_blink_rng.In_chamber_reidentifier.anchor, string) result;
  face_target : unit -> unit;
  trigger_encounter :
    Trigger.config ->
    Bdsp_blink_rng.In_chamber_reidentifier.anchor ->
    (Trigger.outcome, string) result;
  detect_shiny : unit -> R.reading;
  soft_reset : unit -> (unit, string) result;
}

type attempt_result = Hit of E.hit * R.reading | Retry of string

let trigger_config_of_options (opts : Opts.t) =
  let base =
    Trigger.default_config ~target:opts.target
      ~accept:(Opts.accept_pokemon opts.shiny)
  in
  {
    base with
    search = { base.search with synchronize_nature = opts.sync_nature };
    aim_offset_ms = float_of_int opts.delay_ms;
  }

let log_phase ~steps ~attempt ~(opts : Opts.t) phase msg =
  steps.update_counters ~attempt ~max_attempts:opts.max_attempts ~phase;
  steps.log (Printf.sprintf "[attempt %d/%d] %s" attempt opts.max_attempts msg)

let ( let* ) = Result.bind

let run_attempt ~steps ~attempt ~(opts : Opts.t) =
  log_phase ~steps ~attempt ~opts "munchlax_seed"
    "Recovering 128-bit boot seed from Munchlax blinks...";
  let res =
    let* seed = steps.recover_boot_seed ~timeout_s:opts.munchlax_timeout_s in
    log_phase ~steps ~attempt ~opts "enter_save"
      (Printf.sprintf "Seed locked (%d blinks, %.1fs). Entering save..."
         seed.blink_count seed.elapsed_seconds);
    let* () = steps.enter_save () in
    log_phase ~steps ~attempt ~opts "reidentify_1pk"
      "Re-identifying in-chamber 1PK advance anchor...";
    let* anchor = steps.reidentify_in_chamber ~base_state:seed.state in
    steps.face_target ();
    log_phase ~steps ~attempt ~opts "trigger"
      (Printf.sprintf "Anchor locked at adv=%d. Scheduling %s encounter..."
         anchor.advances_to_last_blink opts.target.template.species);
    let* trig =
      steps.trigger_encounter (trigger_config_of_options opts) anchor
    in
    log_phase ~steps ~attempt ~opts "detect_shiny"
      (Printf.sprintf
         "Triggered adv=%d (%s, %s, IVs %s). Watching battle intro..."
         trig.plan.hit.advances
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
      "Soft-resetting via Switch HOME for next attempt...";
    match steps.soft_reset () with
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
