open Blink_extraction

(* [std::llround]: halves away from zero. *)
let cpp_round_to_int value = int_of_float (Float.round value)

(* [std::min]: the first argument unless the second is strictly below it. *)
let cpp_min a b = if b < a then b else a

(* Each event's tick on a grid of [period_seconds] from [origin_seconds], after
   removing the stream's own offset from the grid: the median of the events'
   distances to their nearest tick. Negative ticks become 0. Returns the fitted
   phase offset in ticks alongside the tick indices. *)
let assign_tick_indices_with_phase events period_seconds origin_seconds =
  if events = [] || not (period_seconds > 0.0) then (0.0, [])
  else
    let position (event : blink_event) =
      (event.seconds -. origin_seconds) /. period_seconds
    in
    let deviations =
      List.map
        (fun event -> position event -. Float.round (position event))
        events
      |> Array.of_list
    in
    Array.sort Float.compare deviations;
    let phase_ticks = deviations.(Array.length deviations / 2) in
    let ticks =
      List.map
        (fun event -> max 0 (cpp_round_to_int (position event -. phase_ticks)))
        events
    in
    (phase_ticks, ticks)

let assign_tick_indices events period_seconds origin_seconds =
  snd (assign_tick_indices_with_phase events period_seconds origin_seconds)

(* Every stream is placed on one grid, anchored at whichever blinked first.
   [None] when a stream is empty. *)
let earliest_blink streams =
  if List.exists (fun stream -> stream = []) streams then None
  else
    let first = function
      | (event : blink_event) :: _ -> event.seconds
      | [] -> 0.0
    in
    Some
      (List.fold_left
         (fun earliest stream -> cpp_min earliest (first stream))
         (first (List.hd streams))
         streams)

(* A stream's events as [(tick, event)], plus its fitted phase in ticks, or
   [Error] when two land on one tick. *)
let place_stream stream period_seconds earliest =
  let phase_ticks, ticks =
    assign_tick_indices_with_phase stream period_seconds earliest
  in
  let landed_twice tick = function
    | Some previous -> tick <= previous
    | None -> false
  in
  let rec place previous ticks events =
    match (ticks, events) with
    | tick :: _, _ when landed_twice tick previous ->
        Error
          "Two blinks from the same watcher landed on one tick, so the \
           double-blink grouping is wrong."
    | tick :: ticks, (event : blink_event) :: events ->
        Result.map
          (fun rest -> (tick, event) :: rest)
          (place (Some tick) ticks events)
    | _ -> Ok []
  in
  place None ticks stream |> Result.map (fun events -> (phase_ticks, events))

(* Streams in order; the first stream with two blinks on one tick fails. *)
let place_all streams period_seconds earliest =
  List.fold_left
    (fun placed stream ->
      Result.bind placed (fun placed ->
          place_stream stream period_seconds earliest
          |> Result.map (fun this -> this :: placed)))
    (Ok []) streams
  |> Result.map List.rev

let gap_overlaps ~lo ~hi (gap : frame_gap) =
  gap.start_seconds <= hi && gap.stop_seconds >= lo

let has_gap_in gaps ~lo ~hi = List.exists (gap_overlaps ~lo ~hi) gaps

(* Half-window around an expected tick time in which a capture stall could hide
   an entire blink. *)
let quiet_tick_half_window = 0.35

let observe_event ~double_blink_seconds gaps (event : blink_event) =
  let gap_before =
    has_gap_in gaps
      ~lo:(event.seconds -. double_blink_seconds)
      ~hi:event.seconds
  in
  let gap_after =
    has_gap_in gaps ~lo:event.seconds ~hi:(event.seconds +. double_blink_seconds)
  in
  if gap_before then State_solver.Unknown
  else if event.blink_type = Blink_model.Single && gap_after then
    State_solver.Blinked None
  else State_solver.Blinked (Some event.blink_type)

let observe_quiet ~period_seconds ~earliest ~phase_ticks gaps tick =
  let expected =
    earliest +. ((float_of_int tick +. phase_ticks) *. period_seconds)
  in
  let occluded =
    has_gap_in gaps
      ~lo:(expected -. quiet_tick_half_window)
      ~hi:(expected +. quiet_tick_half_window)
  in
  if occluded then State_solver.Unknown else State_solver.No_blink

let observe_tick ~double_blink_seconds ~period_seconds ~earliest
    (phase_ticks, events) gaps tick =
  match List.assoc_opt tick events with
  | Some event -> observe_event ~double_blink_seconds gaps event
  | None -> observe_quiet ~period_seconds ~earliest ~phase_ticks gaps tick

(* Every roll from the first tick to the last, as seen by every stream. *)
let watched_samples ~double_blink_seconds ~period_seconds ~earliest placed gaps
    slots =
  let npcs = List.length placed in
  let last_tick =
    List.fold_left
      (fun last (_, stream) ->
        List.fold_left (fun last (tick, _) -> max last tick) last stream)
      0 placed
  in
  let stream_specs =
    List.map2 (fun p (g, s) -> (p, g, s)) placed (List.combine gaps slots)
  in
  let sample tick (placed_stream, stream_gaps, slot) =
    {
      State_solver.advance = (tick * npcs) + slot;
      observation =
        observe_tick ~double_blink_seconds ~period_seconds ~earliest
          placed_stream stream_gaps tick;
    }
  in
  List.init (last_tick + 1) (fun tick -> List.map (sample tick) stream_specs)
  |> List.concat
  |> List.stable_sort (fun (a : State_solver.blink_sample) b ->
         Int.compare a.advance b.advance)

(* Advances count from the first sample's, which is always zero in practice. *)
let rebase samples =
  match samples with
  | [] -> []
  | (first : State_solver.blink_sample) :: _ ->
      List.map
        (fun (sample : State_solver.blink_sample) ->
          { sample with advance = sample.advance - first.advance })
        samples

let default_double_blink_seconds = 0.55

let build_from_earliest ~double_blink_seconds ~period_seconds streams ~gaps
    ~slots earliest =
  let to_samples placed =
    rebase
      (watched_samples ~double_blink_seconds ~period_seconds ~earliest placed
         gaps slots)
  in
  Result.map to_samples (place_all streams period_seconds earliest)

let build_samples_with_gaps
    ?(double_blink_seconds = default_double_blink_seconds) streams ~gaps ~slots
    ~period_seconds =
  let lengths_match =
    streams <> []
    && List.length streams = List.length slots
    && List.length streams = List.length gaps
  in
  if not lengths_match then Error "Each stream needs a slot."
  else if not (period_seconds > 0.0) then Error "No tick period was fitted."
  else
    match earliest_blink streams with
    | None -> Error "One of the watchers saw no blinks at all."
    | Some earliest ->
        build_from_earliest ~double_blink_seconds ~period_seconds streams ~gaps
          ~slots earliest

let build_samples streams ~slots ~period_seconds =
  let gaps = List.map (fun _ -> []) streams in
  build_samples_with_gaps streams ~gaps ~slots ~period_seconds

type anchor = { advance : int; seconds : float; stream_index : int }

(* The stream's last blink as an anchor, unless [best] is as late. *)
let later_anchor ~npcs ~period_seconds earliest best (index, stream, slot) =
  let last_tick =
    List.fold_left
      (fun _ tick -> Some tick)
      None
      (assign_tick_indices stream period_seconds earliest)
  in
  let last =
    List.fold_left (fun _ (event : blink_event) -> Some event) None stream
  in
  match (last_tick, last, best) with
  | Some _, Some last, Some anchor when last.seconds <= anchor.seconds -> best
  | Some last_tick, Some last, _ ->
      Some
        {
          advance = (last_tick * npcs) + slot;
          seconds = last.seconds;
          stream_index = index;
        }
  | _ -> best

let last_blink_anchor streams ~slots ~period_seconds =
  let npcs = List.length streams in
  let valid =
    streams <> [] && npcs = List.length slots && period_seconds > 0.0
  in
  let latest earliest =
    List.combine streams slots
    |> List.mapi (fun index (stream, slot) -> (index, stream, slot))
    |> List.fold_left (later_anchor ~npcs ~period_seconds earliest) None
  in
  if valid then Option.bind (earliest_blink streams) latest else None

let step_blink_anchor ~elapsed_seconds ~period_seconds ~npcs ~previous_advance =
  let usable = period_seconds > 0.0 && npcs <> 0 && elapsed_seconds > 0.0 in
  let ticks = cpp_round_to_int (elapsed_seconds /. period_seconds) in
  if usable && ticks > 0 then Some (previous_advance + (ticks * npcs)) else None
