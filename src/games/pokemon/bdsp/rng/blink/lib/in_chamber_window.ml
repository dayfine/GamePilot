module BE = Bdsp_rng.Blink_extraction
module BM = Bdsp_rng.Blink_model
module MR = Bdsp_rng.Mixed_reidentifier
module SR = Bdsp_rng.State_reidentifier

type reid_attempt = {
  result : MR.result;
  blinks : MR.player_blink list;
  unknown_ticks : int list;
  last_ev_s : float;
}

type evaluation =
  | Matched of { result : MR.result; last_ev_s : float }
  | Ambiguous of reid_attempt
  | No_match of reid_attempt

let double_blink_window_s = 0.55
let tick_gap_margin_s = 0.25
let half_divisor = 2.0

let gap_overlaps ~lo ~hi (g : BE.frame_gap) =
  g.stop_seconds >= lo && g.start_seconds <= hi

let has_gap_in gaps ~lo ~hi = List.exists (gap_overlaps ~lo ~hi) gaps

let estimate_period ~tick_seconds events =
  match tick_seconds with
  | Some p -> p
  | None -> (
      match BE.fit_tick_period events with
      | Some fit -> fit.period_seconds
      | None -> BM.npc_tick_seconds)

let classify_event gaps ~first_s ~period (ev : BE.blink_event) =
  let rel_s = ev.seconds -. first_s in
  let tick = int_of_float (Float.round (rel_s /. period)) in
  let pre_gap =
    tick > 0
    && has_gap_in gaps ~lo:(ev.seconds -. double_blink_window_s) ~hi:ev.seconds
  in
  if pre_gap then `Drop tick
  else
    let post_gap =
      ev.blink_type = BM.Single
      && has_gap_in gaps ~lo:ev.seconds ~hi:(ev.seconds +. double_blink_window_s)
    in
    let blink_type = if post_gap then None else Some ev.blink_type in
    `Keep ({ MR.seconds = rel_s; blink_type }, ev.seconds)

let gap_unknown_ticks gaps ~first_s ~period ~last_tick =
  let rec collect tick acc =
    if tick >= last_tick then List.rev acc
    else
      let t_k = first_s +. (float_of_int tick *. period) in
      let hit =
        has_gap_in gaps ~lo:(t_k -. tick_gap_margin_s)
          ~hi:(t_k +. tick_gap_margin_s)
      in
      let acc = if hit then tick :: acc else acc in
      collect (tick + 1) acc
  in
  collect 1 []

let fold_event gaps ~first_s ~period (kept, dropped) ev =
  match classify_event gaps ~first_s ~period ev with
  | `Keep pair -> (pair :: kept, dropped)
  | `Drop tick -> (kept, tick :: dropped)

let build_nonempty_inputs ~tick_seconds ~gaps ~first_s events =
  let period = estimate_period ~tick_seconds events in
  let kept, dropped =
    List.fold_left (fold_event gaps ~first_s ~period) ([], []) events
  in
  let kept = List.rev kept in
  let blinks = List.map fst kept in
  let last_ev_s = match List.rev kept with (_, s) :: _ -> s | [] -> first_s in
  let last_tick =
    int_of_float (Float.round ((last_ev_s -. first_s) /. period))
  in
  let unknown = dropped @ gap_unknown_ticks gaps ~first_s ~period ~last_tick in
  (blinks, unknown, last_ev_s)

let build_reid_inputs ~tick_seconds ~gaps = function
  | [] -> ([], [], 0.0)
  | (first : BE.blink_event) :: _ as events ->
      build_nonempty_inputs ~tick_seconds ~gaps ~first_s:first.seconds events

let run_once ~base_state ~search_min ~search_max ~tick_seconds
    ~order_swap_tolerance ~gaps events =
  let blinks, unknown_ticks, last_ev_s =
    build_reid_inputs ~tick_seconds ~gaps events
  in
  let req : MR.request =
    {
      base_state;
      search_min;
      search_max;
      blinks;
      unknown_ticks;
      tick_seconds;
      order_swap_tolerance;
    }
  in
  let result = SR.reidentify_with_pokemon_models req in
  { result; blinks; unknown_ticks; last_ev_s }

let keep_first_ambiguous ambiguous_opt attempt =
  if attempt.result.ambiguous && Option.is_none ambiguous_opt then Some attempt
  else ambiguous_opt

let fallback_result ~full = function
  | Some attempt -> Ambiguous attempt
  | None -> No_match full

let rec try_suffixes ~run_ev ~min_blinks ~full ~ambiguous_opt = function
  | _ :: rest when List.length rest >= min_blinks ->
      let attempt = run_ev rest in
      if attempt.result.success then
        Matched { result = attempt.result; last_ev_s = attempt.last_ev_s }
      else
        let ambiguous_opt = keep_first_ambiguous ambiguous_opt attempt in
        try_suffixes ~run_ev ~min_blinks ~full ~ambiguous_opt rest
  | _ -> fallback_result ~full ambiguous_opt

let evaluate ~base_state ~search_min ~search_max ~min_blinks ~tick_seconds
    ~order_swap_tolerance ~gaps events =
  let run_ev =
    run_once ~base_state ~search_min ~search_max ~tick_seconds
      ~order_swap_tolerance ~gaps
  in
  let full = run_ev events in
  if full.result.success then
    Matched { result = full.result; last_ev_s = full.last_ev_s }
  else if full.result.ambiguous then Ambiguous full
  else try_suffixes ~run_ev ~min_blinks ~full ~ambiguous_opt:None events

let rec split_pair index = function
  | a :: b :: _ when index = 0 -> Some (a, b)
  | _ :: rest when index > 0 -> split_pair (index - 1) rest
  | _ -> None

let trim_cutoff_seconds ~origin events =
  let count = List.length events in
  if count < 2 then None
  else
    let drop = max 1 (count / 2) in
    match split_pair (drop - 1) events with
    | Some ((prev : BE.blink_event), (next : BE.blink_event)) ->
        Some (origin +. ((prev.seconds +. next.seconds) /. half_divisor))
    | None -> None

let blink_type_tag (b : MR.player_blink) =
  match b.blink_type with
  | Some BM.Single -> "S"
  | Some BM.Double -> "D"
  | None -> "?"

let rec blink_intervals acc = function
  | (a : MR.player_blink) :: ((b : MR.player_blink) :: _ as rest) ->
      let dt = Printf.sprintf "%.2f" (b.seconds -. a.seconds) in
      blink_intervals (dt :: acc) rest
  | _ -> List.rev acc

let format_diagnostics ~blinks ~unknown_ticks ~gaps =
  let count = List.length blinks in
  let types = String.concat "" (List.map blink_type_tag blinks) in
  let intervals = String.concat "," (blink_intervals [] blinks) in
  let unknowns = String.concat "," (List.map string_of_int unknown_ticks) in
  Printf.sprintf "%d blinks; types=%s dt=[%s]s unknown=[%s] gaps=%d" count types
    intervals unknowns (List.length gaps)
