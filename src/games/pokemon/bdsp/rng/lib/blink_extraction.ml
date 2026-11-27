type match_sample = { timestamp : float; score : float }
type blink = { seconds : float; depth : float; frames : int }
type blink_event = { seconds : float; blink_type : Blink_model.blink_type }

type tick_fit = {
  period_seconds : float;
  rms_ticks : float;
  worst_ticks : float;
}

type frame_gap = { start_seconds : float; stop_seconds : float }

let default_max_gap_seconds = 0.065

let gap_between ~origin ~max_gap_seconds a b =
  if b.timestamp -. a.timestamp > max_gap_seconds then
    Some
      {
        start_seconds = a.timestamp -. origin;
        stop_seconds = b.timestamp -. origin;
      }
  else None

let rec scan_frame_gaps ~origin ~max_gap_seconds acc = function
  | a :: (b :: _ as rest) ->
      let acc =
        match gap_between ~origin ~max_gap_seconds a b with
        | Some gap -> gap :: acc
        | None -> acc
      in
      scan_frame_gaps ~origin ~max_gap_seconds acc rest
  | [ _ ] | [] -> List.rev acc

let find_frame_gaps ?origin ?(max_gap_seconds = default_max_gap_seconds) samples
    =
  match samples with
  | [] | [ _ ] -> []
  | first :: _ ->
      let origin = Option.value origin ~default:first.timestamp in
      scan_frame_gaps ~origin ~max_gap_seconds [] samples

let threshold_lowest = 0.04
let threshold_highest = 0.60
let threshold_steps = 40
let minimum_plateau_blinks = 20
let minimum_seconds_for_threshold = 180.0

(* A product rounded on its own, as in Blink_model: ocamlopt's arm64 backend
   would otherwise fuse it with the following add into one FMA. *)
let rounded_product a b = Sys.opaque_identity (a *. b)

(* [std::max] and [std::min]: the first argument unless the second is strictly
   past it, which differs from [Float.max] only for NaN. *)
let cpp_max a b = if a < b then b else a

(* How far each sample falls below the median match, as a fraction of it,
   clamped to [0, 1]. *)
let blink_depths samples =
  let matches = Array.map (fun sample -> sample.score) samples in
  let sorted = Array.copy matches in
  Array.sort Float.compare sorted;
  let count = Array.length sorted in
  let resting = if count = 0 then 0.0 else sorted.(count / 2) in
  if resting <= 0.0 then Array.make count 0.0
  else
    Array.map
      (fun value ->
        let depth = (resting -. value) /. resting in
        if depth < 0.0 then 0.0 else if depth > 1.0 then 1.0 else depth)
      matches

let count_blinks depths threshold =
  let count, _ =
    Array.fold_left
      (fun (count, shut) depth ->
        if depth > threshold then ((if shut then count else count + 1), true)
        else (count, false))
      (0, false) depths
  in
  count

(* The run of thresholds from [start] whose counts stay at the minimum or more
   and within one of [counts.(start)]; returns its last index. *)
let rec plateau_end counts start last =
  let next = last + 1 in
  if
    next < threshold_steps
    && counts.(next) >= minimum_plateau_blinks
    && abs (counts.(next) - counts.(start)) <= 1
  then plateau_end counts start next
  else last

(* The widest plateau as [(span, start, end)]; strictly wider, so that a tie
   keeps the lower-threshold plateau. *)
let rec widest_plateau counts c best =
  if c >= threshold_steps then best
  else if counts.(c) < minimum_plateau_blinks then
    widest_plateau counts (c + 1) best
  else
    let last = plateau_end counts c c in
    let wider =
      match best with Some (span, _, _) -> last - c > span | None -> true
    in
    widest_plateau counts (last + 1)
      (if wider then Some (last - c, c, last) else best)

let threshold_ladder () =
  let low = log threshold_lowest in
  let high = log threshold_highest in
  Array.init threshold_steps (fun c ->
      exp
        (low
        +. (high -. low) *. float_of_int c
           /. float_of_int (threshold_steps - 1)))

let auto_blink_threshold samples =
  let samples = Array.of_list samples in
  let count = Array.length samples in
  let watched () = samples.(count - 1).timestamp -. samples.(0).timestamp in
  if count = 0 || watched () < minimum_seconds_for_threshold then None
  else
    let depths = blink_depths samples in
    let thresholds = threshold_ladder () in
    let counts = Array.map (count_blinks depths) thresholds in
    widest_plateau counts 0 None
    |> Option.map (fun (_, start, last) ->
           exp ((log thresholds.(start) +. log thresholds.(last)) /. 2.0))

(* Samples either side of a run that its centre is weighted over. *)
let blink_border = 2

(* The blink of the run [start, stop): its depth-weighted centre over the run
   and [blink_border] samples either side, or [None] if that has no weight. *)
let blink_of_run samples depths origin ~start ~stop =
  let from = max (start - blink_border) 0 in
  let upto = min (stop + blink_border) (Array.length depths) in
  let weight = ref 0.0 in
  let weighted_time = ref 0.0 in
  let peak = ref 0.0 in
  for i = from to upto - 1 do
    let seconds = samples.(i).timestamp -. origin in
    weight := !weight +. depths.(i);
    weighted_time := !weighted_time +. rounded_product depths.(i) seconds;
    peak := cpp_max !peak depths.(i)
  done;
  if !weight <= 0.0 then None
  else
    Some
      {
        seconds = !weighted_time /. !weight;
        depth = !peak;
        frames = stop - start;
      }

let extract_blinks ?origin samples ~threshold =
  let samples = Array.of_list samples in
  if Array.length samples < 2 || threshold <= 0.0 then []
  else
    let depths = blink_depths samples in
    let origin = Option.value origin ~default:samples.(0).timestamp in
    let count = Array.length depths in
    let blinks = ref [] in
    let start = ref 0 in
    let shut = ref false in
    for c = 0 to count do
      let now_shut = c < count && depths.(c) > threshold in
      if now_shut && not !shut then (
        shut := true;
        start := c)
      else if (not now_shut) && !shut then (
        shut := false;
        blink_of_run samples depths origin ~start:!start ~stop:c
        |> Option.iter (fun blink -> blinks := blink :: !blinks))
    done;
    List.rev !blinks

let group_blinks ?(double_blink_seconds = 0.55) (blinks : blink list) =
  let rec group = function
    | (first : blink) :: second :: rest
      when second.seconds -. first.seconds < double_blink_seconds ->
        { seconds = first.seconds; blink_type = Double } :: group rest
    | first :: rest ->
        { seconds = first.seconds; blink_type = Single } :: group rest
    | [] -> []
  in
  group blinks

let fit_steps = 400
let fewest_fitted_events = 3

(* RMS and worst distance of the gaps to whole ticks of [period]. *)
let tick_errors gaps period =
  let total, worst =
    Array.fold_left
      (fun (total, worst) gap ->
        let ticks = gap /. period in
        let error = Float.abs (ticks -. Float.round ticks) in
        (total +. rounded_product error error, cpp_max worst error))
      (0.0, 0.0) gaps
  in
  (sqrt (total /. float_of_int (Array.length gaps)), worst)

let fit_tick_period ?(lowest_seconds = 1.000) ?(highest_seconds = 1.040)
    (events : blink_event list) =
  let seconds =
    Array.of_list (List.map (fun (e : blink_event) -> e.seconds) events)
  in
  if Array.length seconds < fewest_fitted_events then None
  else
    let gaps =
      Array.init
        (Array.length seconds - 1)
        (fun c -> seconds.(c + 1) -. seconds.(c))
    in
    let best =
      ref { period_seconds = 0.0; rms_ticks = 0.0; worst_ticks = 0.0 }
    in
    for c = 0 to fit_steps do
      let period =
        lowest_seconds
        +. (highest_seconds -. lowest_seconds)
           *. float_of_int c /. float_of_int fit_steps
      in
      let rms, worst = tick_errors gaps period in
      if !best.period_seconds = 0.0 || rms < !best.rms_ticks then
        best :=
          { period_seconds = period; rms_ticks = rms; worst_ticks = worst }
    done;
    Some !best
