(* Blink extraction and the blink grid against the C++'s golden vectors
   (fixtures/blink_extraction.txt). Match scores are written in thousandths and
   timestamps in whole microseconds; both are read back exactly as the C++
   built its samples from them. *)

open Bdsp_rng
open Blink_extraction

let records = Fixture_lines.read "fixtures/blink_extraction.txt"
let float17 = Fixture_lines.float17
let microseconds = 1e6
let thousandths = 1000.0

let take count items =
  ( List.filteri (fun c _ -> c < count) items,
    List.filteri (fun c _ -> c >= count) items )

(* "<start_us> <step_us> <count> <thousandths...>" *)
let match_samples = function
  | start :: step :: count :: rest ->
      let start = int_of_string start and step = int_of_string step in
      List.mapi
        (fun c milli ->
          {
            timestamp = float_of_int (start + (c * step)) /. microseconds;
            score = float_of_string milli /. thousandths;
          })
        (fst (take (int_of_string count) rest))
  | _ -> failwith "samples: start step count values"

let blink_lines blinks =
  List.map
    (fun (b : blink) ->
      Printf.sprintf "\n  blink %s %s %d" (float17 b.seconds) (float17 b.depth)
        b.frames)
    blinks
  |> String.concat ""

let type_char = function Blink_model.Single -> 'S' | Double -> 'D'

let events_text events =
  String.concat " "
    (string_of_int (List.length events)
    :: List.map
         (fun (e : blink_event) ->
           Printf.sprintf "%s%c" (float17 e.seconds) (type_char e.blink_type))
         events)

let fit_text = function
  | Some fit ->
      String.concat " "
        (List.map float17
           [ fit.period_seconds; fit.rms_ticks; fit.worst_ticks ])
  | None -> "0 0 0"

let threshold_text threshold =
  "threshold " ^ float17 (Option.value threshold ~default:(-1.0))

let extract_stream inputs =
  let samples = match_samples inputs in
  let threshold = auto_blink_threshold samples in
  let blinks =
    Option.fold ~none:[]
      ~some:(fun threshold -> extract_blinks samples ~threshold)
      threshold
  in
  let events = group_blinks blinks in
  Printf.sprintf "%s%s\n  events %s\n  fit %s" (threshold_text threshold)
    (blink_lines blinks) (events_text events)
    (fit_text (fit_tick_period events))

let extract_short = function
  | threshold :: origin :: rest ->
      let samples = match_samples rest in
      let origin =
        match int_of_string origin with
        | 0 -> None
        | us -> Some (float_of_int us /. microseconds)
      in
      threshold_text (auto_blink_threshold samples)
      ^ blink_lines
          (extract_blinks ?origin samples
             ~threshold:(float_of_string threshold))
  | _ -> failwith "extract_short: threshold origin samples"

let seconds_list count rest = List.map float_of_string (fst (take count rest))

let group = function
  | window :: count :: rest ->
      let blinks =
        List.map
          (fun seconds -> { seconds; depth = 0.0; frames = 0 })
          (seconds_list (int_of_string count) rest)
      in
      events_text
        (group_blinks ~double_blink_seconds:(float_of_string window) blinks)
  | _ -> failwith "group: window count seconds"

let fit = function
  | lowest :: highest :: count :: rest ->
      let events =
        List.map
          (fun seconds -> { seconds; blink_type = Blink_model.Single })
          (seconds_list (int_of_string count) rest)
      in
      fit_text
        (fit_tick_period ~lowest_seconds:(float_of_string lowest)
           ~highest_seconds:(float_of_string highest) events)
  | _ -> failwith "fit: lowest highest count seconds"

let event_of_token token =
  let last = String.length token - 1 in
  {
    seconds = float_of_string (String.sub token 0 last);
    blink_type = (if token.[last] = 'S' then Single else Double);
  }

(* "<period> <slot count> <slots...> <stream count> (<count> <events...>)..." *)
let placement = function
  | period :: slot_count :: rest ->
      let slots, rest = take (int_of_string slot_count) rest in
      let rec streams count rest =
        if count = 0 then []
        else
          let events, rest =
            take (int_of_string (List.hd rest)) (List.tl rest)
          in
          List.map event_of_token events :: streams (count - 1) rest
      in
      ( float_of_string period,
        List.map int_of_string slots,
        streams (int_of_string (List.hd rest)) (List.tl rest) )
  | _ -> failwith "placement: period slots streams"

let npc_result_text (r : State_solver.blink_solve_result) =
  Printf.sprintf "%d %s %d %d %d reason=%s" (Bool.to_int r.success)
    (String.concat " "
       (List.map Fixture_lines.hex32
          [ r.state.s0; r.state.s1; r.state.s2; r.state.s3 ]))
    r.advances_to_last_blink r.equations_used r.null_space_dimension
    r.failure_reason

let sample_text (s : State_solver.blink_sample) =
  let kind = Option.fold ~none:'?' ~some:type_char s.blink_type in
  Printf.sprintf " %d%c" s.advance kind

let build inputs =
  let period_seconds, slots, streams = placement inputs in
  match Blink_grid.build_samples streams ~slots ~period_seconds with
  | Error reason -> "fail reason=" ^ reason
  | Ok samples ->
      Printf.sprintf "ok %d%s\n  solve %s" (List.length samples)
        (List.filter (fun (s : State_solver.blink_sample) -> s.blinked) samples
        |> List.map sample_text |> String.concat "")
        (npc_result_text
           (Result.get_ok (State_solver.solve_state_from_samples samples)))

let anchor inputs =
  let period_seconds, slots, streams = placement inputs in
  match Blink_grid.last_blink_anchor streams ~slots ~period_seconds with
  | Some a ->
      Printf.sprintf "1 %d %s %d" a.advance (float17 a.seconds) a.stream_index
  | None -> "0"

let step_anchor = function
  | [ elapsed; period; npcs; previous ] -> (
      let previous_advance = int_of_string previous in
      match
        Blink_grid.step_blink_anchor ~elapsed_seconds:(float_of_string elapsed)
          ~period_seconds:(float_of_string period) ~npcs:(int_of_string npcs)
          ~previous_advance
      with
      | Some advance -> Printf.sprintf "1 %d" advance
      | None -> Printf.sprintf "0 %d" previous_advance)
  | _ -> failwith "step_anchor: elapsed period npcs previous"

let () =
  let check = Fixture_lines.check_op records in
  check "extract_stream" extract_stream;
  check "extract_short" extract_short;
  check "group" group;
  check "fit" fit;
  check "build_samples" build;
  check "anchor" anchor;
  check "step_anchor" step_anchor;
  Table_test.finish ()
