open Blink_extraction

type config = {
  npcs : int;
  min_rolls_to_try : int;
  confirmation_events : int;
  window_events : int;
  max_failed_windows : int;
  liveness_timeout_seconds : int;
  reanchor_blinks : int;
  reanchor_search_radius : int;
}

let default_config =
  {
    npcs = 2;
    min_rolls_to_try = 44;
    confirmation_events = 6;
    window_events = 52;
    max_failed_windows = 3;
    liveness_timeout_seconds = 3600;
    reanchor_blinks = 6;
    reanchor_search_radius = 600;
  }

type recovery = {
  state : Xorshift128.state;
  clock : Advance_clock.t;
  events : int;
  thresholds : float list;
  slots : int list;
  anchor_stream : int;
}

type waiting =
  | No_samples
  | No_threshold
  | Not_fresh
  | Too_few_blinks
  | No_tick_fit
  | Confirming
  | Too_few_rolls
  | Unsolved

type decision =
  | Keep_collecting of waiting
  | Provisional of { state : Xorshift128.state; events : int }
  | Changed of { state : Xorshift128.state; events : int }
  | Dropped
  | Confirmed of recovery
  | Gave_up of string

type outcome = {
  decision : decision;
  events : int option;
  discard_before : float option;
}

type t = {
  config : config;
  deadline : float;
  failed_solves : int;
  thresholds : Recovery_thresholds.t;
  newest_blinks : float option list;
  provisional : Provisional_state.t;
}

let start config ~watchers ~now =
  {
    config;
    deadline = now +. float_of_int config.liveness_timeout_seconds;
    failed_solves = 0;
    thresholds = Recovery_thresholds.start ~watchers;
    newest_blinks = List.init watchers (fun _ -> None);
    provisional = Provisional_state.empty;
  }

let seconds_per_minute = 60

let gave_up loop ~now =
  let give_up_after =
    loop.config.max_failed_windows * loop.config.window_events
  in
  if loop.failed_solves >= give_up_after then
    Some (Printf.sprintf "no RNG state solved over %d blinks" give_up_after)
  else if now > loop.deadline then
    Some
      (Printf.sprintf "no RNG state solved in %d minutes"
         (loop.config.liveness_timeout_seconds / seconds_per_minute))
  else None

(* [collect_blink_matches]: the earliest first sample, or [None] while a watcher
   has none. *)
let origin_of matches =
  let first = function
    | (sample : match_sample) :: _ -> Some sample.timestamp
    | [] -> None
  in
  List.fold_left
    (fun origin samples ->
      match (origin, first samples) with
      | Some origin, Some at -> Some (if at < origin then at else origin)
      | _ -> None)
    (Some infinity) matches

let solve_attempt streams ~slots ~period_seconds =
  match Blink_grid.build_samples streams ~slots ~period_seconds with
  | Error _ -> None
  | Ok samples ->
      let result = State_solver.solve_state_from_samples samples in
      if result.success then Some (result.state, slots) else None

let rotate = function [] -> [] | first :: rest -> rest @ [ first ]

(* One solve per rotation of the watchers' order, until one succeeds. *)
let solve streams ~period_seconds =
  let rec attempt remaining slots =
    if remaining = 0 then None
    else
      match solve_attempt streams ~slots ~period_seconds with
      | Some solved -> Some solved
      | None -> attempt (remaining - 1) (rotate slots)
  in
  let count = List.length streams in
  attempt count (List.init count Fun.id)

let anchor_failure =
  "the RNG state was found but no blink could anchor the clock"

let recovery loop ~origin ~events ~period_seconds (state, slots)
    (anchor : Blink_grid.anchor) =
  let clock : Advance_clock.t =
    {
      anchor_time = Advance_clock.plus_seconds origin anchor.seconds;
      anchor_advance = anchor.advance;
      tick_seconds = period_seconds;
      npcs = loop.config.npcs;
    }
  in
  {
    state;
    clock;
    events;
    thresholds =
      Option.value (Recovery_thresholds.frozen loop.thresholds) ~default:[];
    slots;
    anchor_stream = anchor.stream_index;
  }

let confirmed loop streams ~origin ~events ~period_seconds solved =
  match
    Blink_grid.last_blink_anchor streams ~slots:(snd solved) ~period_seconds
  with
  | None -> Gave_up anchor_failure
  | Some anchor ->
      Confirmed (recovery loop ~origin ~events ~period_seconds solved anchor)

let solve_pass loop streams ~origin ~thresholds ~events ~period_seconds =
  let solved = solve streams ~period_seconds in
  let provisional, step =
    Provisional_state.update loop.provisional (Option.map fst solved) ~events
      ~confirmation_events:loop.config.confirmation_events
  in
  let loop =
    {
      loop with
      failed_solves = (if solved = None then loop.failed_solves + 1 else 0);
      thresholds =
        (if solved <> None then
           Recovery_thresholds.freeze loop.thresholds thresholds
         else loop.thresholds);
      provisional;
    }
  in
  let decision =
    match (step, solved) with
    | Provisional, Some (state, _) -> Provisional { state; events }
    | Changed, Some (state, _) -> Changed { state; events }
    | Dropped, _ -> Dropped
    | Confirmed, Some solved ->
        confirmed loop streams ~origin ~events ~period_seconds solved
    | _ -> Keep_collecting Unsolved
  in
  (loop, decision)

(* [window_start]: one cut for every watcher, a second before the oldest of the
   newest [window_events] blinks across all of them, so no stream reads blinks
   cut from it as rolls that did not blink. *)
let window_start config streams ~origin =
  let seconds =
    List.concat_map
      (List.map (fun (event : blink_event) -> event.seconds))
      streams
    |> List.sort compare
  in
  let count = List.length seconds in
  if count <= config.window_events then None
  else
    let oldest_kept = List.nth seconds (count - config.window_events) in
    Some (Advance_clock.plus_seconds origin (oldest_kept -. 1.0))

(* A watcher's blink is new when it is over a second after the newest seen. *)
let seen_blink newest_blink newest =
  match newest_blink with
  | None -> (true, newest)
  | Some seen ->
      ( newest > Advance_clock.plus_seconds seen 1.0,
        if seen < newest then newest else seen )

let refresh newest_blink stream ~origin =
  match List.rev stream with
  | [] -> (newest_blink, false)
  | (last : blink_event) :: _ ->
      let fresh, kept =
        seen_blink newest_blink (Advance_clock.plus_seconds origin last.seconds)
      in
      (Some kept, fresh)

let longest streams =
  List.fold_left
    (fun best stream ->
      if List.length stream > List.length best then stream else best)
    (List.hd streams) streams

let minimum_blinks = 3

(* [solve_window_once]'s checks before a solve, in the C++'s order. *)
let ready loop streams ~events =
  let longest = longest streams in
  let confirming =
    match loop.provisional.held with
    | Some held -> events < held.events + loop.config.confirmation_events
    | None -> false
  in
  if List.length longest < minimum_blinks then Error Too_few_blinks
  else
    match fit_tick_period longest with
    | Some fit when fit.period_seconds > 0.0 ->
        if confirming then Error Confirming
        else if events < loop.config.min_rolls_to_try then Error Too_few_rolls
        else Ok fit.period_seconds
    | _ -> Error No_tick_fit

(* [solve_blink_window]: one solve, then the window slides, only while no state
   is held: a state is confirmed against the same oldest blink it was solved
   from. *)
let solve_blink_window loop streams ~origin ~thresholds ~events =
  let loop, decision =
    match ready loop streams ~events with
    | Error waiting -> (loop, Keep_collecting waiting)
    | Ok period_seconds ->
        solve_pass loop streams ~origin ~thresholds ~events ~period_seconds
  in
  let discard_before =
    match loop.provisional.held with
    | None -> window_start loop.config streams ~origin
    | Some _ -> None
  in
  (loop, decision, discard_before)

let streams_pass loop matches ~origin ~thresholds =
  let streams =
    List.map2
      (fun samples threshold ->
        group_blinks (extract_blinks ~origin samples ~threshold))
      matches thresholds
  in
  let events =
    List.fold_left (fun total stream -> total + List.length stream) 0 streams
  in
  let refreshed =
    List.map2
      (fun newest_blink stream -> refresh newest_blink stream ~origin)
      loop.newest_blinks streams
  in
  let loop = { loop with newest_blinks = List.map fst refreshed } in
  let loop, decision, discard_before =
    if List.exists snd refreshed then
      solve_blink_window loop streams ~origin ~thresholds ~events
    else (loop, Keep_collecting Not_fresh, None)
  in
  (loop, { decision; events = Some events; discard_before })

let no_streams decision = { decision; events = None; discard_before = None }

let thresholds_pass loop matches ~origin =
  match Recovery_thresholds.thresholds loop.thresholds matches with
  | thresholds, None ->
      ({ loop with thresholds }, no_streams (Keep_collecting No_threshold))
  | state, Some thresholds ->
      streams_pass { loop with thresholds = state } matches ~origin ~thresholds

let poll loop ~now matches =
  match (gave_up loop ~now, origin_of matches) with
  | Some reason, _ -> (loop, no_streams (Gave_up reason))
  | None, None -> (loop, no_streams (Keep_collecting No_samples))
  | None, Some origin -> thresholds_pass loop matches ~origin
