open Blink_model

(* Rows of bits 22, 21, 20 and 19: the top of the fraction a Pokemon blink
   interval encodes. *)
let pokemon_blink_bit_row_first = 105
let target_usable = 40.0
let count_headroom = 1.1
let minimum_usable_fraction = 0.1
let count_when_hopeless = 1000

let recommended_pokemon_blink_count tolerance_seconds =
  let bucket_seconds =
    (pokemon_blink_max_seconds -. pokemon_blink_min_seconds)
    /. float_of_int (1 lsl pokemon_blink_known_bits)
  in
  let usable_fraction = 1.0 -. (2.0 *. tolerance_seconds /. bucket_seconds) in
  if not (usable_fraction > minimum_usable_fraction) then count_when_hopeless
  else
    (* 40 observations is 160 (not necessarily independent) equations for 128
       unknowns, which is usually enough. *)
    int_of_float (target_usable /. usable_fraction *. count_headroom) + 1

type request = {
  intervals : float list;
  tolerance_seconds : float;
  max_attempts : int;
}

type result = {
  success : bool;
  state : Xorshift128.state;
  advances_to_last_interval : int;
  observations_used : int;
  observations_discarded : int;
  equations_used : int;
  null_space_dimension : int;
  attempts : int;
  weakest_margin_used : float;
  mistimed_intervals : int;
  worst_residual_seconds : float;
  failure_reason : string;
}

let failure reason =
  {
    success = false;
    state = { Xorshift128.s0 = 0; s1 = 0; s2 = 0; s3 = 0 };
    advances_to_last_interval = 0;
    observations_used = 0;
    observations_discarded = 0;
    equations_used = 0;
    null_space_dimension = 0;
    attempts = 0;
    weakest_margin_used = 0.0;
    mistimed_intervals = 0;
    worst_residual_seconds = 0.0;
    failure_reason = reason;
  }

(* One in eight, and never fewer than two, so that a short capture is not held
   to a stricter standard than a long one. *)
let mistimes_per_interval = 8
let fewest_allowed_mistimes = 2

(* The worst residual over the agreeing intervals (so that it measures the
   timing precision rather than the size of an outlier) and the count of
   mistimed ones, or why the state is rejected. *)
let verify_pokemon_solution state intervals tolerance_seconds =
  let rng = Xorshift128.create state in
  let worst = ref 0.0 in
  let mistimed = ref 0 in
  List.iter
    (fun interval ->
      let expected = pokemon_blink_interval (Xorshift128.next rng) in
      let residual = Float.abs (interval -. expected) in
      if residual > tolerance_seconds then incr mistimed
      else if residual > !worst then worst := residual)
    intervals;
  let count = List.length intervals in
  let allowed = max fewest_allowed_mistimes (count / mistimes_per_interval) in
  if !mistimed > allowed then
    Error
      (Printf.sprintf
         "%d of %d intervals disagree with the recovered state, which is too \
          many to blame on mistimed blinks."
         !mistimed count)
  else Ok (!worst, !mistimed)

type reading = { index : int; bucket : int; margin : float }

(* Usable readings, most room first; the index breaks ties so the choice of
   subset is reproducible. *)
let more_confident a b =
  if a.margin <> b.margin then Float.compare b.margin a.margin
  else Int.compare a.index b.index

let sorted_readings intervals =
  let reading index interval =
    (* [None]: not a gap the game could ever have produced. *)
    pokemon_blink_bucket_with_margin interval
    |> Option.map (fun (bucket, margin) -> { index; bucket; margin })
  in
  let readings =
    List.mapi reading intervals |> List.filter_map Fun.id |> Array.of_list
  in
  Array.stable_sort more_confident readings;
  readings

(* Every blink costs exactly one advance, so interval [c] comes from roll
   [c + 1]: its transition is the step matrix to the [c + 1]th power. *)
let transitions count =
  let step = Xorshift128.transition_matrix in
  let table = Array.make count step in
  for c = 1 to count - 1 do
    table.(c) <- Gf2_matrix.mul step table.(c - 1)
  done;
  table

(* A reading's bucket bits, most significant first, matching the row order. *)
let reading_equations transition reading =
  List.init pokemon_blink_known_bits (fun bit ->
      let shift = pokemon_blink_known_bits - 1 - bit in
      ( Gf2_matrix.row transition (pokemon_blink_bit_row_first + bit),
        (reading.bucket lsr shift) land 1 <> 0 ))

(* The equations of [readings.(0 .. use - 1)] without [omitted], with the
   weakest margin used and the reading count. *)
let subset_equations readings transitions ~use ~omitted =
  let chosen =
    Array.to_list (Array.sub readings 0 use)
    |> List.filteri (fun c _ -> c <> omitted)
  in
  let rows, constants =
    List.concat_map
      (fun reading -> reading_equations transitions.(reading.index) reading)
      chosen
    |> List.split
  in
  let weakest = List.fold_left (fun _ reading -> reading.margin) 0.0 chosen in
  (Array.of_list rows, Array.of_list constants, weakest, List.length chosen)

let minimum_readings = Gf2_matrix.dimension / pokemon_blink_known_bits

(* What the subsets tried so far left behind. *)
type search = {
  mutable last_failure : string;
  mutable attempts : int;
  mutable null_space_dimension : int;
}

type outcome = Found of result | Next | Stop

let found request ~state ~fit:(residual, mistimed) ~equations ~weakest ~count
    search =
  let total = List.length request.intervals in
  {
    success = true;
    state;
    advances_to_last_interval = total - 1;
    observations_used = count;
    observations_discarded = total - count;
    equations_used = equations;
    null_space_dimension = 0;
    attempts = search.attempts;
    weakest_margin_used = weakest;
    mistimed_intervals = mistimed;
    worst_residual_seconds = residual;
    failure_reason = "";
  }

(* The candidates of one subset's solution, checked against every interval. *)
let check_candidates request solved search =
  let fit = ref (0.0, 0) in
  let verifier state =
    match
      verify_pokemon_solution state request.intervals request.tolerance_seconds
    with
    | Ok state_fit ->
        fit := state_fit;
        true
    | Error reason ->
        if search.last_failure = "" then search.last_failure <- reason;
        false
  in
  match Null_space_search.count_verified solved verifier with
  | 1, Some state -> Some (state, !fit)
  | verified, _ ->
      if verified > 1 then
        search.last_failure <- "More than one state fits these intervals.";
      None

let try_subset request readings transitions search ~use ~omitted =
  let rows, constants, weakest, count =
    subset_equations readings transitions ~use ~omitted
  in
  let solved = Gf2_matrix.solve rows constants in
  let dimension = Array.length solved.null_space_basis in
  if not solved.consistent then (
    search.last_failure <- "The intervals contradict each other.";
    Next)
  else if dimension > Null_space_search.max_enumerated_bits then (
    (* Leaving more out can only make this worse. *)
    search.null_space_dimension <- dimension;
    search.last_failure <-
      Printf.sprintf
        "The intervals leave %d unknown bits, too many to resolve by checking."
        dimension;
    Stop)
  else
    let found (state, fit) =
      Found
        (found request ~state ~fit ~equations:(Array.length rows) ~weakest
           ~count search)
    in
    Option.fold ~none:Next ~some:found (check_candidates request solved search)

(* Trial 0 uses the whole confident set; trial [n > 0] leaves out the [n]th
   least confident reading of it, while that stays above the minimum. *)
let rec run_trials request readings transitions search ~use trial =
  let leave_one_out = trial > 0 in
  if trial >= request.max_attempts then None
  else if leave_one_out && (use <= minimum_readings || trial > use) then None
  else (
    search.attempts <- trial + 1;
    let omitted = if leave_one_out then use - trial else use in
    match try_subset request readings transitions search ~use ~omitted with
    | Found result -> Some result
    | Stop -> None
    | Next -> run_trials request readings transitions search ~use (trial + 1))

let rec confident_count readings tolerance_seconds count =
  if
    count < Array.length readings
    && readings.(count).margin >= tolerance_seconds
  then confident_count readings tolerance_seconds (count + 1)
  else count

let search_failure search ~discarded =
  let reason =
    if search.last_failure = "" then
      "Could not recover a state from these intervals."
    else
      Printf.sprintf
        "%s Tried %d subsets of the most confident observations without \
         success. At least one interval was probably mistimed; collect more \
         blinks."
        search.last_failure search.attempts
  in
  {
    (failure reason) with
    observations_discarded = discarded;
    attempts = search.attempts;
    null_space_dimension = search.null_space_dimension;
  }

let solve_usable request readings =
  let total = List.length request.intervals in
  let usable = Array.length readings in
  let confident = confident_count readings request.tolerance_seconds 0 in
  let use = max confident minimum_readings in
  let transitions = transitions total in
  let search = { last_failure = ""; attempts = 0; null_space_dimension = 0 } in
  match run_trials request readings transitions search ~use 0 with
  | Some result -> result
  | None -> search_failure search ~discarded:(total - usable)

let too_few_usable ~usable ~total =
  {
    (failure
       (Printf.sprintf
          "Only %d of %d intervals were usable at all. At least %d are needed. \
           Collect more blinks."
          usable total minimum_readings))
    with
    observations_discarded = total - usable;
  }

let solve_state_from_pokemon_blinks request =
  let total = List.length request.intervals in
  let readings = lazy (sorted_readings request.intervals) in
  if total = 0 then failure "No intervals were given."
  else if not (request.tolerance_seconds > 0.0) then
    failure "The tolerance must be positive."
  else if Array.length (Lazy.force readings) < minimum_readings then
    too_few_usable ~usable:(Array.length (Lazy.force readings)) ~total
  else solve_usable request (Lazy.force readings)
