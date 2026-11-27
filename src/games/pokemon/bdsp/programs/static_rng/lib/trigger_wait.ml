type wait_defaults = {
  ms_per_s : float;
  secs_per_min : float;
  poll_ms : int;
  handoff_guard_ms : float;
  reanchor_min_advances : int;
  reanchor_lead_ms : float;
  reanchor_window : int;
  search_min_floor : int;
  lease_ms : float;
  keepawake_ms : float;
  keepawake_press_ms : int;
  log_ms : float;
}

let cfg =
  {
    ms_per_s = 1000.0;
    secs_per_min = 60.0;
    poll_ms = 500;
    handoff_guard_ms = 2_500.0;
    reanchor_min_advances = 180;
    reanchor_lead_ms = 120_000.0;
    reanchor_window = 240;
    search_min_floor = 50;
    lease_ms = 30_000.0;
    keepawake_ms = 90_000.0;
    keepawake_press_ms = 50;
    log_ms = 60_000.0;
  }

let send_keepawake () =
  let cmd =
    Wire.press ~hold_ms:cfg.keepawake_press_ms
      ~cooldown_ms:cfg.keepawake_press_ms [ Wire.LStick ]
  in
  ignore (Effects.submit [ cmd ] : Wire.batch_done)

let rec wait_loop ~log ~target_adv ~stop_ms ~open_t_ms ~last_lease ~last_ka
    ~last_log =
  let now = Effects.now () in
  let last_lease =
    if now -. last_lease >= cfg.lease_ms then (
      Effects.renew_lease ();
      now)
    else last_lease
  in
  let last_ka =
    if now -. last_ka >= cfg.keepawake_ms then (
      send_keepawake ();
      now)
    else last_ka
  in
  let last_log =
    if now -. last_log >= cfg.log_ms then (
      let rem_s = Float.max 0.0 ((open_t_ms -. now) /. cfg.ms_per_s) in
      log
        (Printf.sprintf "Countdown: %.0fs remaining until adv=%d..." rem_s
           target_adv);
      now)
    else last_log
  in
  if now >= stop_ms then ()
  else (
    ignore
      (Effects.await ~timeout_ms:cfg.poll_ms (fun (m : Effects.measurements) ->
           m.t_ms >= stop_ms)
        : Effects.awaited);
    wait_loop ~log ~target_adv ~stop_ms ~open_t_ms ~last_lease ~last_ka
      ~last_log)

let wait_on_probes ~picture ~log ~target_adv ~stop_ms ~open_t_ms =
  let probes = Bdsp_readers.Battle_detector.probes ~picture in
  Effects.with_probes probes (fun () ->
      let now = Effects.now () in
      wait_loop ~log ~target_adv ~stop_ms ~open_t_ms ~last_lease:now
        ~last_ka:now ~last_log:now)

let log_planned_hit ~log (tcfg : Bdsp_blink_rng.Static_rng_trigger.config)
    (p : Bdsp_blink_rng.Static_rng_trigger.plan) ~now =
  let wait_s = Float.max 0.0 ((p.open_t_ms -. now) /. cfg.ms_per_s) in
  log
    (Printf.sprintf
       "Planned %s at adv=%d (%s, %s, IVs %s) — waiting %.0fs (%.1f min)..."
       tcfg.target.template.species p.hit.advances
       (Bdsp_rng.Static_encounter.shiny_name p.hit.pokemon.shiny)
       (Bdsp_rng.Static_encounter.nature_name p.hit.pokemon.nature)
       (Bdsp_rng.Static_encounter.ivs_to_string p.hit.pokemon.ivs)
       wait_s
       (wait_s /. cfg.secs_per_min))

let maybe_reanchor ~picture ~log ~reidentify_with_bounds tcfg
    (anchor : Bdsp_blink_rng.In_chamber_reidentifier.anchor)
    (p : Bdsp_blink_rng.Static_rng_trigger.plan) =
  let gap_adv = p.hit.advances - anchor.advances_to_last_blink in
  if gap_adv <= cfg.reanchor_min_advances then Ok (anchor, p)
  else
    let reanchor_stop_ms = p.open_t_ms -. cfg.reanchor_lead_ms in
    log
      (Printf.sprintf
         "Target adv=%d is %d advances away — waiting for final zero-drift 1PK \
          re-anchor..."
         p.hit.advances gap_adv);
    wait_on_probes ~picture ~log ~target_adv:p.hit.advances
      ~stop_ms:reanchor_stop_ms ~open_t_ms:p.open_t_ms;
    let est_adv =
      max cfg.search_min_floor (p.hit.advances - cfg.reanchor_min_advances)
    in
    let search_min = max cfg.search_min_floor (est_adv - cfg.reanchor_window) in
    let search_max = p.hit.advances in
    log
      (Printf.sprintf "Running final 1PK re-anchor in [%d..%d]..." search_min
         search_max);
    let ( let* ) = Result.bind in
    let* (anchor2 : Bdsp_blink_rng.In_chamber_reidentifier.anchor) =
      reidentify_with_bounds ~search_min ~search_max
    in
    log
      (Printf.sprintf "Final 1PK anchor locked at adv=%d (tick=%.4fs)."
         anchor2.advances_to_last_blink anchor2.fitted_tick_seconds);
    let* p2 = Bdsp_blink_rng.Static_rng_trigger.plan tcfg anchor2 in
    Ok (anchor2, p2)

let run_final ~log ~prepare_for_trigger tcfg anchor
    (p : Bdsp_blink_rng.Static_rng_trigger.plan) () =
  let now = Effects.now () in
  log_planned_hit ~log tcfg p ~now;
  let stop_ms = p.open_t_ms -. cfg.handoff_guard_ms in
  wait_loop ~log ~target_adv:p.hit.advances ~stop_ms ~open_t_ms:p.open_t_ms
    ~last_lease:now ~last_ka:now ~last_log:now;
  prepare_for_trigger ();
  Bdsp_blink_rng.Static_rng_trigger.run tcfg anchor

let run ~picture ~log ~prepare_for_trigger ~reidentify_with_bounds tcfg anchor =
  let ( let* ) = Result.bind in
  let* p0 = Bdsp_blink_rng.Static_rng_trigger.plan tcfg anchor in
  log_planned_hit ~log tcfg p0 ~now:(Effects.now ());
  let* anchor_final, p_final =
    maybe_reanchor ~picture ~log ~reidentify_with_bounds tcfg anchor p0
  in
  let probes = Bdsp_readers.Battle_detector.probes ~picture in
  Effects.with_probes probes
    (run_final ~log ~prepare_for_trigger tcfg anchor_final p_final)
