module EBR = Bdsp_readers.Eye_blink_reader
module BE = Bdsp_rng.Blink_extraction
module BM = Bdsp_rng.Blink_model
module PBS = Bdsp_rng.Pokemon_blink_solver
module XS = Bdsp_rng.Xorshift128

type config = {
  picture : Wire.box;
  target : EBR.target;
  tolerance_seconds : float;
  max_blinks : int;
  timeout_seconds : float;
  lease_renew_seconds : float;
  confirmation_blinks : int;
  max_attempts : int;
}

type outcome = {
  state : XS.state;
  solve : PBS.result;
  blink_count : int;
  gaps : BE.frame_gap list;
  threshold : float;
  elapsed_seconds : float;
}

let min_usable_intervals = 32
let ms_per_s = 1000.0
let poll_timeout_ms = 1000
let check_period_s = 1.0
let reestimate_divisor = 4

let max_pokemon_interval =
  BM.pokemon_blink_max_seconds +. BM.pokemon_blink_offset_seconds

let default_config ~picture ~template =
  {
    picture;
    target = EBR.munchlax_target ~template;
    tolerance_seconds = 0.10;
    max_blinks = 140;
    timeout_seconds = 1500.0;
    lease_renew_seconds = 30.0;
    confirmation_blinks = 6;
    max_attempts = 64;
  }

type candidate = { state : XS.state; blink_count : int }

type watch_state = {
  start_s : float;
  mutable last_seq : int;
  mutable last_lease_s : float;
  mutable last_check_s : float;
  mutable samples_rev : BE.match_sample list;
  mutable raw_gaps_rev : Wire.gap list;
  mutable sample_count : int;
}

type solver_state = {
  mutable frozen_threshold : float option;
  mutable est_threshold : float option;
  mutable est_from : int;
  mutable blink_count : int;
  mutable candidate : candidate option;
}

let make_watch start_s =
  {
    start_s;
    last_seq = -1;
    last_lease_s = start_s;
    last_check_s = start_s;
    samples_rev = [];
    raw_gaps_rev = [];
    sample_count = 0;
  }

let make_solver () =
  {
    frozen_threshold = None;
    est_threshold = None;
    est_from = 0;
    blink_count = 0;
    candidate = None;
  }

let now_seconds () = Effects.now () /. ms_per_s

let maybe_renew_lease config watch now_s =
  if now_s -. watch.last_lease_s >= config.lease_renew_seconds then (
    Effects.renew_lease ();
    watch.last_lease_s <- now_s)

let drain_gaps watch =
  let incoming = Effects.take_gaps () in
  List.iter (fun g -> watch.raw_gaps_rev <- g :: watch.raw_gaps_rev) incoming

let record_frame config watch (frame : Effects.measurements) =
  watch.last_seq <- frame.seq;
  match EBR.score frame config.target.id with
  | None -> ()
  | Some score ->
      let sample : BE.match_sample =
        { timestamp = frame.t_ms /. ms_per_s; score }
      in
      watch.samples_rev <- sample :: watch.samples_rev;
      watch.sample_count <- watch.sample_count + 1

let frame_gaps_of ~origin raw_gaps_rev =
  List.rev_map
    (fun (g : Wire.gap) ->
      {
        BE.start_seconds = (g.from_t_ms /. ms_per_s) -. origin;
        stop_seconds = (g.to_t_ms /. ms_per_s) -. origin;
      })
    raw_gaps_rev

(* Longest contiguous run of valid inter-blink intervals so a long capture stall
   that dropped a blink cannot shift roll indices for the rest of the run. *)
let contiguous_intervals ~tolerance (blinks : BE.blink list) =
  let max_dt = max_pokemon_interval +. tolerance in
  let rec scan best cur = function
    | (a : BE.blink) :: (b :: _ as rest) ->
        let dt = b.seconds -. a.seconds in
        if dt > max_dt then
          let best = if List.length cur > List.length best then cur else best in
          scan best [] rest
        else scan best (dt :: cur) rest
    | [ _ ] | [] ->
        let best = if List.length cur > List.length best then cur else best in
        List.rev best
  in
  scan [] [] blinks

let count_usable ~tolerance intervals =
  List.fold_left
    (fun acc dt ->
      match BM.pokemon_blink_bucket_with_margin dt with
      | Some (_, margin) when margin >= tolerance -> acc + 1
      | _ -> acc)
    0 intervals

let resolve_threshold solver samples sample_count =
  match solver.frozen_threshold with
  | Some t -> Some t
  | None ->
      let should_est =
        Option.is_none solver.est_threshold
        || sample_count
           >= solver.est_from + (solver.est_from / reestimate_divisor)
      in
      if should_est then (
        solver.est_threshold <- BE.auto_blink_threshold samples;
        solver.est_from <- sample_count);
      solver.est_threshold

let ready_for_solve config solver count =
  match solver.candidate with
  | None -> true
  | Some c -> count >= c.blink_count + config.confirmation_blinks

let apply_solve_result solver count (res : PBS.result) =
  if not res.success then `Continue
  else
    match solver.candidate with
    | Some c when c.state = res.state -> `Confirmed (res, count)
    | _ ->
        solver.candidate <- Some { state = res.state; blink_count = count };
        `Continue

let solve_now config solver ~threshold intervals count =
  if Option.is_none solver.frozen_threshold then
    solver.frozen_threshold <- Some threshold;
  if not (ready_for_solve config solver count) then `Continue
  else
    let req : PBS.request =
      {
        intervals;
        tolerance_seconds = config.tolerance_seconds;
        max_attempts = config.max_attempts;
      }
    in
    apply_solve_result solver count (PBS.solve_state_from_pokemon_blinks req)

let try_solve_new_count config solver ~threshold blinks count =
  solver.blink_count <- count;
  let intervals =
    contiguous_intervals ~tolerance:config.tolerance_seconds blinks
  in
  let usable = count_usable ~tolerance:config.tolerance_seconds intervals in
  if usable < min_usable_intervals then `Continue
  else solve_now config solver ~threshold intervals count

let try_solve config solver ~threshold blinks =
  let count = List.length blinks in
  if count = solver.blink_count then `Continue
  else try_solve_new_count config solver ~threshold blinks count

let confirmed_outcome watch ~origin ~threshold ~now_s ~solve ~blink_count =
  let gaps = frame_gaps_of ~origin watch.raw_gaps_rev in
  let elapsed_seconds = now_s -. watch.start_s in
  Ok
    {
      state = solve.PBS.state;
      solve;
      blink_count;
      gaps;
      threshold;
      elapsed_seconds;
    }

let check_with_threshold config watch solver ~origin ~now_s threshold =
  let blinks = BE.extract_blinks (List.rev watch.samples_rev) ~threshold in
  match try_solve config solver ~threshold blinks with
  | `Confirmed (solve, blink_count) ->
      `Done
        (confirmed_outcome watch ~origin ~threshold ~now_s ~solve ~blink_count)
  | `Continue when List.length blinks >= config.max_blinks ->
      let msg =
        Printf.sprintf "Munchlax_seed_finder: reached %d blinks"
          config.max_blinks
      in
      `Done (Error msg)
  | `Continue -> `Continue

let check_nonempty config watch solver ~now_s (first : BE.match_sample) samples
    =
  match resolve_threshold solver samples watch.sample_count with
  | None -> `Continue
  | Some threshold ->
      check_with_threshold config watch solver ~origin:first.timestamp ~now_s
        threshold

let check_samples config watch solver now_s =
  match List.rev watch.samples_rev with
  | [] -> `Continue
  | first :: _ as samples ->
      check_nonempty config watch solver ~now_s first samples

let await_next_frame config watch =
  let pred (m : Effects.measurements) = m.seq > watch.last_seq in
  match Effects.await ~timeout_ms:poll_timeout_ms pred with
  | Effects.Holds frame -> record_frame config watch frame
  | Effects.Timeout -> ()

let rec step_after_frame config watch solver =
  drain_gaps watch;
  let now_s = now_seconds () in
  maybe_renew_lease config watch now_s;
  if now_s -. watch.last_check_s < check_period_s then loop config watch solver
  else (
    watch.last_check_s <- now_s;
    match check_samples config watch solver now_s with
    | `Done outcome -> outcome
    | `Continue -> loop config watch solver)

and loop config watch solver =
  let now_s = now_seconds () in
  maybe_renew_lease config watch now_s;
  drain_gaps watch;
  if now_s -. watch.start_s >= config.timeout_seconds then
    Error
      (Printf.sprintf "Munchlax_seed_finder: timed out after %.1f s"
         config.timeout_seconds)
  else (
    await_next_frame config watch;
    step_after_frame config watch solver)

let watch_and_solve config () =
  let start_s = now_seconds () in
  loop config (make_watch start_s) (make_solver ())

let run config =
  match EBR.probes ~picture:config.picture [ config.target ] with
  | [] -> Error "Munchlax_seed_finder: eye ROI lies outside game picture"
  | probes -> Effects.with_probes probes (watch_and_solve config)
