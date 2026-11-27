module EBR = Bdsp_readers.Eye_blink_reader
module BE = Bdsp_rng.Blink_extraction
module BR = Bdsp_rng.Blink_recovery
module XS = Bdsp_rng.Xorshift128

type config = {
  picture : Wire.box;
  target : EBR.target;
  min_rolls_to_try : int;
  timeout_seconds : float;
  lease_renew_seconds : float;
}

type outcome = {
  state : XS.state;
  events : int;
  tick_seconds : float;
  elapsed_seconds : float;
}

type timing_defaults = {
  ms_per_s : float;
  poll_timeout_ms : int;
  check_period_s : float;
  min_rolls : int;
  timeout_s : float;
  lease_renew_s : float;
  keepawake_s : float;
  keepawake_press_ms : int;
}

let defaults =
  {
    ms_per_s = 1000.0;
    poll_timeout_ms = 1000;
    check_period_s = 1.0;
    min_rolls = 38;
    timeout_s = 600.0;
    lease_renew_s = 30.0;
    keepawake_s = 90.0;
    keepawake_press_ms = 50;
  }

let default_config ~picture ~target =
  {
    picture;
    target;
    min_rolls_to_try = defaults.min_rolls;
    timeout_seconds = defaults.timeout_s;
    lease_renew_seconds = defaults.lease_renew_s;
  }

type watch_state = {
  start_s : float;
  mutable last_lease_s : float;
  mutable last_keepawake_s : float;
  mutable last_check_s : float;
  mutable samples_rev : BE.match_sample list;
  mutable recovery : BR.t;
}

let now_seconds () = Effects.now () /. defaults.ms_per_s

let make_watch config start_s =
  let br_cfg =
    {
      BR.default_config with
      npcs = 1;
      min_rolls_to_try = config.min_rolls_to_try;
    }
  in
  {
    start_s;
    last_lease_s = start_s;
    last_keepawake_s = start_s;
    last_check_s = start_s;
    samples_rev = [];
    recovery = BR.start br_cfg ~watchers:1 ~now:start_s;
  }

let send_keepawake () =
  let cmd =
    Wire.press ~hold_ms:defaults.keepawake_press_ms
      ~cooldown_ms:defaults.keepawake_press_ms [ Wire.LStick ]
  in
  ignore (Effects.submit [ cmd ] : Wire.batch_done)

let maybe_renew_lease config watch now_s =
  if now_s -. watch.last_lease_s >= config.lease_renew_seconds then (
    Effects.renew_lease ();
    watch.last_lease_s <- now_s);
  if now_s -. watch.last_keepawake_s >= defaults.keepawake_s then (
    send_keepawake ();
    watch.last_keepawake_s <- now_s)

let record_frame config watch (frame : Effects.measurements) =
  match EBR.score frame config.target.id with
  | None -> ()
  | Some score ->
      let sample : BE.match_sample =
        { timestamp = frame.t_ms /. defaults.ms_per_s; score }
      in
      watch.samples_rev <- sample :: watch.samples_rev

let keep_after cutoff (s : BE.match_sample) = s.timestamp >= cutoff

let apply_discard watch = function
  | None -> ()
  | Some cutoff ->
      watch.samples_rev <- List.filter (keep_after cutoff) watch.samples_rev

let outcome_of_recovery watch now_s (r : BR.recovery) =
  {
    state = r.state;
    events = r.events;
    tick_seconds = r.clock.tick_seconds;
    elapsed_seconds = now_s -. watch.start_s;
  }

let try_poll watch now_s =
  let samples = List.rev watch.samples_rev in
  let next_rec, out = BR.poll watch.recovery ~now:now_s [ samples ] in
  watch.recovery <- next_rec;
  apply_discard watch out.discard_before;
  match out.decision with
  | BR.Confirmed r -> Some (Ok (outcome_of_recovery watch now_s r))
  | BR.Gave_up reason -> Some (Error ("Pedestal_seed_finder: " ^ reason))
  | BR.Keep_collecting _ | BR.Provisional _ | BR.Changed _ | BR.Dropped -> None

let await_frame_batch config watch =
  ignore
    (Effects.await ~timeout_ms:defaults.poll_timeout_ms
       (fun (m : Effects.measurements) ->
         record_frame config watch m;
         (m.t_ms /. defaults.ms_per_s) -. watch.last_check_s
         >= defaults.check_period_s)
      : Effects.awaited)

let rec poll_and_continue config watch =
  let check_s = now_seconds () in
  if check_s -. watch.last_check_s < defaults.check_period_s then
    collect config watch
  else (
    watch.last_check_s <- check_s;
    match try_poll watch check_s with
    | Some result -> result
    | None -> collect config watch)

and collect config watch =
  let now_s = now_seconds () in
  maybe_renew_lease config watch now_s;
  if now_s -. watch.start_s >= config.timeout_seconds then
    Error
      (Printf.sprintf "Pedestal_seed_finder: timed out after %.0fs"
         config.timeout_seconds)
  else (
    await_frame_batch config watch;
    poll_and_continue config watch)

let run config =
  let probes = EBR.probes ~picture:config.picture [ config.target ] in
  Effects.with_probes probes (fun () ->
      let watch = make_watch config (now_seconds ()) in
      collect config watch)
