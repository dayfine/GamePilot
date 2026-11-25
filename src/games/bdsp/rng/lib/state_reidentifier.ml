type observation =
  | Intervals of int list
  | Types of Blink_model.blink_type list

type request = {
  base_state : Xorshift128.state;
  search_min : int;
  search_max : int;
  npcs : int;
  observation : observation;
}

type result = {
  success : bool;
  ambiguous : bool;
  match_count : int;
  advances_to_first_blink : int;
  advances_to_last_blink : int;
  failure_reason : string;
}

let max_matches_tracked = 8

let failure ?(match_count = 0) ?(ambiguous = false) reason =
  {
    success = false;
    ambiguous;
    match_count;
    advances_to_first_blink = 0;
    advances_to_last_blink = 0;
    failure_reason = reason;
  }

let succeeded ~first ~last =
  {
    success = true;
    ambiguous = false;
    match_count = 1;
    advances_to_first_blink = first;
    advances_to_last_blink = last;
    failure_reason = "";
  }

let no_match_reason what =
  Printf.sprintf "No position in the search range fits the observed %s." what

let ambiguous_reason what count =
  Printf.sprintf
    "The observed %s fit %d positions. Narrow the search range or collect more \
     blinks."
    what count

(* No match, or more than one, for the observed [what]. *)
let match_failure ~what count =
  if count = 0 then failure (no_match_reason what)
  else failure ~match_count:count ~ambiguous:true (ambiguous_reason what count)

(* Bits 1-3 of each roll say whether a blink happened, bit 0 which kind. *)
let nibble_mask = 0x0f

let generate_nibbles base_state count =
  let rng = Xorshift128.create base_state in
  Bytes.init count (fun _ -> Char.chr (Xorshift128.next rng land nibble_mask))

let nibble_blinked nibbles index =
  Blink_model.npc_blinks (Char.code (Bytes.get nibbles index))

let nibble_type nibbles index =
  Blink_model.npc_blink_type (Char.code (Bytes.get nibbles index))

(* No blink in any tick strictly between, and one at the end. *)
let rec gaps_match nibbles stride position = function
  | [] -> true
  | interval :: rest ->
      let quiet tick =
        not (nibble_blinked nibbles (position + (tick * stride)))
      in
      let next = position + (interval * stride) in
      List.for_all quiet (List.init (interval - 1) (fun tick -> tick + 1))
      && nibble_blinked nibbles next
      && gaps_match nibbles stride next rest

(* How many starts in the range fit (stopping at the cap), and the first. *)
let count_interval_matches request nibbles intervals =
  let rec scan start count first =
    if start > request.search_max || count >= max_matches_tracked then
      (count, first)
    else if
      nibble_blinked nibbles start
      && gaps_match nibbles request.npcs start intervals
    then scan (start + 1) (count + 1) (if count = 0 then start else first)
    else scan (start + 1) count first
  in
  scan request.search_min 0 0

let reidentify_by_intervals request intervals =
  if List.mem 0 intervals then
    failure "An interval of zero was given. Two blinks cannot share a tick."
  else
    let span = List.fold_left ( + ) 0 intervals * request.npcs in
    let nibbles =
      generate_nibbles request.base_state (request.search_max + span + 1)
    in
    match count_interval_matches request nibbles intervals with
    | 1, first -> succeeded ~first ~last:(first + span)
    | count, _ -> match_failure ~what:"blinks" count

(* Blinks average one in eight ticks; this allows for uncommonly spaced ones. *)
let reach_ticks_per_blink = 64

(* One bit per blink: [observed] types can tell at most [2^observed] starts
   apart. The C++ compares [2^observed] as a 64-bit shift only below 64 types;
   an OCaml range is below [2^62], so from 62 types on the answer is "enough"
   either way. *)
let too_few_types observed range =
  let int_bits = Sys.int_size - 1 in
  observed < int_bits && 1 lsl observed < range

(* The blinks on the rolls [phase, phase + stride, ...]: their positions and
   types, in order. *)
let phase_blinks nibbles stride phase =
  let count = (Bytes.length nibbles - phase + stride - 1) / stride in
  List.init count (fun c -> phase + (c * stride))
  |> List.filter (nibble_blinked nibbles)
  |> List.map (fun index -> (index, nibble_type nibbles index))
  |> Array.of_list

(* Matches of [types] starting at a blink in the search range, as
   [(count, first match's start and last blink)]. *)
let phase_matches request types blinks (count, found) =
  let observed = Array.length types in
  let matches_at start =
    let position = fst blinks.(start) in
    position >= request.search_min
    && position <= request.search_max
    && Array.for_all Fun.id
         (Array.init observed (fun c -> snd blinks.(start + c) = types.(c)))
  in
  List.init (max 0 (Array.length blinks - observed + 1)) Fun.id
  |> List.filter matches_at
  |> List.fold_left
       (fun (count, found) start ->
         let span = (fst blinks.(start), fst blinks.(start + observed - 1)) in
         (count + 1, if count = 0 then span else found))
       (count, found)

let count_type_matches request types nibbles =
  let rec scan phase tally =
    if phase >= request.npcs || fst tally >= max_matches_tracked then tally
    else
      let blinks = phase_blinks nibbles request.npcs phase in
      let tally =
        if Array.length blinks < Array.length types then tally
        else phase_matches request types blinks tally
      in
      scan (phase + 1) tally
  in
  scan 0 (0, (0, 0))

let reidentify_by_types request types =
  let types = Array.of_list types in
  let observed = Array.length types in
  let range = request.search_max - request.search_min + 1 in
  if too_few_types observed range then
    failure
      (Printf.sprintf
         "Only %d blink types for a range of %d advances. This cannot identify \
          a unique position."
         observed range)
  else
    let reach = observed * reach_ticks_per_blink * request.npcs in
    let nibbles =
      generate_nibbles request.base_state (request.search_max + reach + 1)
    in
    match count_type_matches request types nibbles with
    | 1, (first, last) -> succeeded ~first ~last
    | count, _ -> match_failure ~what:"blink types" count

let reidentify_advances request =
  if request.npcs = 0 then failure "There must be at least one NPC on screen."
  else if request.search_min > request.search_max then
    failure "The search range is empty."
  else
    match request.observation with
    | Intervals [] -> failure "No intervals were given."
    | Intervals intervals -> reidentify_by_intervals request intervals
    | Types [] -> failure "No blink types were given."
    | Types types -> reidentify_by_types request types
