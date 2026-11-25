open Blink_extraction

(* [std::llround]: halves away from zero. *)
let cpp_round_to_int value = int_of_float (Float.round value)

(* [std::min]: the first argument unless the second is strictly below it. *)
let cpp_min a b = if b < a then b else a

(* Each event's tick on a grid of [period_seconds] from [origin_seconds], after
   removing the stream's own offset from the grid: the median of the events'
   distances to their nearest tick. Negative ticks become 0. *)
let assign_tick_indices events period_seconds origin_seconds =
  if events = [] || not (period_seconds > 0.0) then []
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
    List.map
      (fun event -> max 0 (cpp_round_to_int (position event -. phase_ticks)))
      events

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

(* A stream's events as [(tick, type)], or [Error] when two land on one tick. *)
let place_stream stream period_seconds earliest =
  let ticks = assign_tick_indices stream period_seconds earliest in
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
          (fun rest -> (tick, event.blink_type) :: rest)
          (place (Some tick) ticks events)
    | _ -> Ok []
  in
  place None ticks stream

(* Streams in order; the first stream with two blinks on one tick fails. *)
let place_all streams period_seconds earliest =
  List.fold_left
    (fun placed stream ->
      Result.bind placed (fun placed ->
          place_stream stream period_seconds earliest
          |> Result.map (fun this -> this :: placed)))
    (Ok []) streams
  |> Result.map List.rev

(* Every roll from the first tick to the last, as seen by every stream. *)
let watched_samples placed slots =
  let npcs = List.length placed in
  let last_tick =
    List.fold_left
      (fun last stream ->
        List.fold_left (fun last (tick, _) -> max last tick) last stream)
      0 placed
  in
  let sample tick stream slot =
    let seen = List.assoc_opt tick stream in
    {
      State_solver.advance = (tick * npcs) + slot;
      blinked = Option.is_some seen;
      blink_type = seen;
    }
  in
  List.init (last_tick + 1) (fun tick -> List.map2 (sample tick) placed slots)
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

let build_samples streams ~slots ~period_seconds =
  if streams = [] || List.length streams <> List.length slots then
    Error "Each stream needs a slot."
  else if not (period_seconds > 0.0) then Error "No tick period was fitted."
  else
    match earliest_blink streams with
    | None -> Error "One of the watchers saw no blinks at all."
    | Some earliest ->
        place_all streams period_seconds earliest
        |> Result.map (fun placed -> rebase (watched_samples placed slots))

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
