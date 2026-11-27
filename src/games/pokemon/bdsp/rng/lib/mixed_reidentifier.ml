type player_blink = {
  seconds : float;
  blink_type : Blink_model.blink_type option;
}

type request = {
  base_state : Xorshift128.state;
  search_min : int;
  search_max : int;
  blinks : player_blink list;
  unknown_ticks : int list;
  tick_seconds : float option;
  order_swap_tolerance : float;
}

type result = {
  success : bool;
  ambiguous : bool;
  match_count : int;
  fitted_tick_seconds : float;
  advances_to_first_blink : int;
  advances_to_last_blink : int;
  next_pokemon_blink_min_seconds : float;
  next_pokemon_blink_max_seconds : float;
  failure_reason : string;
}

let default_order_swap_tolerance = 0.08
let max_matches_tracked = 8
let nibble_mask = 0x0f
let drift_per_tick = 0.0003

let min_pk_interval =
  Blink_model.pokemon_blink_min_seconds
  +. Blink_model.pokemon_blink_offset_seconds

let max_pk_interval =
  Blink_model.pokemon_blink_max_seconds
  +. Blink_model.pokemon_blink_offset_seconds

let make_result ~success ~ambiguous ~match_count ~period ~first ~last ~pk_min
    ~pk_max ~reason =
  {
    success;
    ambiguous;
    match_count;
    fitted_tick_seconds = period;
    advances_to_first_blink = first;
    advances_to_last_blink = last;
    next_pokemon_blink_min_seconds = pk_min;
    next_pokemon_blink_max_seconds = pk_max;
    failure_reason = reason;
  }

let failure ?(match_count = 0) ?(ambiguous = false) ~period reason =
  make_result ~success:false ~ambiguous ~match_count ~period ~first:0 ~last:0
    ~pk_min:0.0 ~pk_max:0.0 ~reason

let succeeded ~period ~first ~last ~pk_min ~pk_max =
  make_result ~success:true ~ambiguous:false ~match_count:1 ~period ~first ~last
    ~pk_min ~pk_max ~reason:""

let event_of_blink (b : player_blink) : Blink_extraction.blink_event =
  { seconds = b.seconds; blink_type = Single }

let fit_period_from_blinks blinks =
  let events = List.map event_of_blink blinks in
  match Blink_extraction.fit_tick_period events with
  | Some fit -> fit.period_seconds
  | None -> Blink_model.npc_tick_seconds

let fit_period request =
  match request.tick_seconds with
  | Some period -> period
  | None -> fit_period_from_blinks request.blinks

let rec build_ticks ~origin ~period previous acc = function
  | [] -> Ok (List.rev acc)
  | (blink : player_blink) :: rest ->
      let tick =
        int_of_float (Float.round ((blink.seconds -. origin) /. period))
      in
      if tick <= previous then
        Error "Two player blinks landed on the same tick."
      else
        build_ticks ~origin ~period tick ((tick, blink.blink_type) :: acc) rest

let assign_ticks blinks ~period =
  match blinks with
  | [] -> Error "No player blinks were given."
  | first :: _ -> build_ticks ~origin:first.seconds ~period (-1) [] blinks

let build_expected_ticks placed unknown_ticks =
  let last_tick = fst (List.hd (List.rev placed)) in
  let expected = Array.make (last_tick + 1) State_solver.No_blink in
  List.iter
    (fun tick ->
      if tick > 0 && tick < last_tick then
        expected.(tick) <- State_solver.Unknown)
    unknown_ticks;
  List.iter
    (fun (tick, blink_type) ->
      expected.(tick) <- State_solver.Blinked blink_type)
    placed;
  expected

type tables = { nibbles : bytes; pkmn_dt : float array }

let build_tables base_state count =
  let rng = Xorshift128.create base_state in
  let nibbles = Bytes.create count in
  let pkmn_dt = Array.make count 0.0 in
  for i = 0 to count - 1 do
    let roll = Xorshift128.next rng in
    Bytes.set nibbles i (Char.chr (roll land nibble_mask));
    pkmn_dt.(i) <- Blink_model.pokemon_blink_interval roll
  done;
  { nibbles; pkmn_dt }

let matches_obs tables index = function
  | State_solver.Unknown -> true
  | State_solver.No_blink ->
      not (Blink_model.npc_blinks (Char.code (Bytes.get tables.nibbles index)))
  | State_solver.Blinked None ->
      Blink_model.npc_blinks (Char.code (Bytes.get tables.nibbles index))
  | State_solver.Blinked (Some seen) ->
      let byte = Char.code (Bytes.get tables.nibbles index) in
      Blink_model.npc_blinks byte && Blink_model.npc_blink_type byte = seen

type found_end = { last : int; pk_min : float; pk_max : float }

let merge_end ends ~last ~pk_min ~pk_max =
  let pk_min = Float.max 0.0 pk_min in
  let pk_max = Float.max pk_min pk_max in
  let rec update = function
    | [] -> [ { last; pk_min; pk_max } ]
    | item :: rest when item.last = last ->
        {
          last;
          pk_min = Float.min item.pk_min pk_min;
          pk_max = Float.max item.pk_max pk_max;
        }
        :: rest
    | item :: rest -> item :: update rest
  in
  update ends

type search_ctx = {
  tables : tables;
  expected : State_solver.observation array;
  last_tick : int;
  period : float;
  base_tol : float;
}

let tol_at ctx k = ctx.base_tol +. (drift_per_tick *. float_of_int k)

let explore_from ctx ~k ~adv ~pk_lo ~pk_hi ends =
  let last_time = float_of_int ctx.last_tick *. ctx.period in
  let limit = Bytes.length ctx.tables.nibbles in
  let rec dfs k adv pk_lo pk_hi ends =
    if List.length ends >= 2 then ends
    else if k > ctx.last_tick then
      merge_end ends ~last:(adv - 1) ~pk_min:(pk_lo -. last_time)
        ~pk_max:(pk_hi -. last_time)
    else if adv >= limit then ends
    else
      let t_k = float_of_int k *. ctx.period in
      let tol = tol_at ctx k in
      let ends =
        if pk_lo <= t_k +. tol then
          let hi' = Float.min pk_hi (t_k +. tol) in
          let dt = ctx.tables.pkmn_dt.(adv) in
          dfs k (adv + 1) (pk_lo +. dt) (hi' +. dt) ends
        else ends
      in
      if pk_hi >= t_k -. tol && matches_obs ctx.tables adv ctx.expected.(k) then
        let lo' = Float.max pk_lo (t_k -. tol) in
        dfs (k + 1) (adv + 1) lo' pk_hi ends
      else ends
  in
  dfs k adv pk_lo pk_hi ends

let try_no_pokemon_blink ctx start ends =
  let last_time = float_of_int ctx.last_tick *. ctx.period in
  if last_time <= max_pk_interval +. tol_at ctx ctx.last_tick then
    merge_end ends ~last:(start + ctx.last_tick) ~pk_min:0.0
      ~pk_max:(max_pk_interval -. last_time)
  else ends

let try_pokemon_first_at ctx start k_first ends =
  let a1 = start + k_first in
  let lo1 =
    Float.max 0.0
      ((float_of_int (k_first - 1) *. ctx.period) -. tol_at ctx (k_first - 1))
  in
  let hi1 =
    Float.min max_pk_interval
      ((float_of_int k_first *. ctx.period) +. tol_at ctx k_first)
  in
  if lo1 <= hi1 then
    let dt1 = ctx.tables.pkmn_dt.(a1) in
    explore_from ctx ~k:k_first ~adv:(a1 + 1) ~pk_lo:(lo1 +. dt1)
      ~pk_hi:(hi1 +. dt1) ends
  else ends

let prefix_mismatches ctx start k_first =
  k_first > 1
  && not
       (matches_obs ctx.tables (start + k_first - 1) ctx.expected.(k_first - 1))

let rec try_first_slots ctx start ~max_k_first k_first ends =
  if k_first > max_k_first || List.length ends >= 2 then ends
  else if prefix_mismatches ctx start k_first then ends
  else if k_first = ctx.last_tick + 1 then try_no_pokemon_blink ctx start ends
  else
    let ends = try_pokemon_first_at ctx start k_first ends in
    try_first_slots ctx start ~max_k_first (k_first + 1) ends

let match_candidate ctx start =
  if not (matches_obs ctx.tables start ctx.expected.(0)) then []
  else
    let max_k_first =
      min (ctx.last_tick + 1)
        (int_of_float (Float.ceil (max_pk_interval /. ctx.period)) + 1)
    in
    try_first_slots ctx start ~max_k_first 1 []

let record_candidate_matches start count first = function
  | [] -> (count, first)
  | [ only ] ->
      let first = if count = 0 then Some (start, only) else first in
      (count + 1, first)
  | head :: _ as several ->
      let first = if count = 0 then Some (start, head) else first in
      (min max_matches_tracked (count + List.length several), first)

let scan_range ctx ~search_min ~search_max =
  let rec scan start count first =
    if start > search_max || count >= max_matches_tracked then (count, first)
    else
      let count, first =
        record_candidate_matches start count first (match_candidate ctx start)
      in
      scan (start + 1) count first
  in
  scan search_min 0 None

let ambiguous_message count =
  Printf.sprintf
    "The observed 1PK player blinks fit %d positions. Narrow the search range \
     or collect more blinks."
    count

let result_of_scan ~period = function
  | 1, Some (first, found) ->
      succeeded ~period ~first ~last:found.last ~pk_min:found.pk_min
        ~pk_max:found.pk_max
  | 0, _ ->
      failure ~period
        "No position in the search range fits the observed 1PK player blinks."
  | count, _ ->
      failure ~match_count:count ~ambiguous:true ~period
        (ambiguous_message count)

let run_search request ~period expected =
  let last_tick = Array.length expected - 1 in
  let total_seconds = float_of_int last_tick *. period in
  let max_pk_blinks =
    int_of_float (Float.ceil (total_seconds /. min_pk_interval)) + 2
  in
  let count = request.search_max + last_tick + max_pk_blinks + 3 in
  let tables = build_tables request.base_state count in
  let ctx =
    {
      tables;
      expected;
      last_tick;
      period;
      base_tol = request.order_swap_tolerance;
    }
  in
  scan_range ctx ~search_min:request.search_min ~search_max:request.search_max
  |> result_of_scan ~period

let reidentify request =
  let period = fit_period request in
  if request.search_min < 0 || request.search_min > request.search_max then
    failure ~period "The search range is empty."
  else if not (period > 0.0) then
    failure ~period "No positive tick period was available."
  else if request.order_swap_tolerance < 0.0 then
    failure ~period "Order-swap tolerance must be non-negative."
  else
    match assign_ticks request.blinks ~period with
    | Error reason -> failure ~period reason
    | Ok placed ->
        let expected = build_expected_ticks placed request.unknown_ticks in
        run_search request ~period expected
