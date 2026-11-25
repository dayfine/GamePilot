(* Re-anchoring against the C++'s golden vectors (fixtures/blink_recovery.txt,
   "reanchor" lines): the clock after, as the C++ leaves it, and the note it
   logs. *)

open Bdsp_rng

let records = Fixture_lines.read "fixtures/blink_recovery.txt"
let us = 1e6

let event text : Blink_extraction.blink_event =
  let length = String.length text in
  {
    seconds = float_of_string (String.sub text 0 (length - 1));
    blink_type = (if text.[length - 1] = 'S' then Single else Double);
  }

let rec streams count tokens =
  match (count, tokens) with
  | 0, _ -> []
  | _, events :: rest ->
      let n = int_of_string events in
      List.map event (List.filteri (fun i _ -> i < n) rest)
      :: streams (count - 1) (List.filteri (fun i _ -> i >= n) rest)
  | _, [] -> failwith "missing stream"

let note = function
  | Ok (r : Blink_reanchor.reanchored) ->
      Printf.sprintf
        "Re-anchored at advance %d, %.3fs (%.2f advances) off what the clock \
         predicted."
        r.clock.anchor_advance r.drift_seconds r.drift_advances
  | Error (Blink_reanchor.Not_reidentified reason) ->
      "Absolute re-anchor found nothing usable, so the stepped clock stands. "
      ^ reason
  | Error (Too_few_blinks | Shared_tick) -> ""

let reanchor = function
  | s0 :: s1 :: s2 :: s3 :: anchor_stream :: blinks :: radius :: origin_us
    :: anchor_us :: anchor_advance :: tick :: npcs :: count :: tokens ->
      let word = Fixture_lines.hex in
      let origin = float_of_string origin_us /. us in
      let clock : Advance_clock.t =
        {
          anchor_time = float_of_string anchor_us /. us;
          anchor_advance = int_of_string anchor_advance;
          tick_seconds = float_of_string tick;
          npcs = int_of_string npcs;
        }
      in
      let config =
        {
          Blink_recovery.default_config with
          reanchor_blinks = int_of_string blinks;
          reanchor_search_radius = int_of_string radius;
        }
      in
      let recovery : Blink_recovery.recovery =
        {
          state = { s0 = word s0; s1 = word s1; s2 = word s2; s3 = word s3 };
          clock;
          events = 0;
          thresholds = [];
          slots = [];
          anchor_stream = int_of_string anchor_stream;
        }
      in
      let result =
        Blink_reanchor.reanchor_absolute config recovery
          (streams (int_of_string count) tokens)
          ~origin clock
      in
      let after, ok =
        match result with Ok r -> (r.clock, 1) | Error _ -> (clock, 0)
      in
      Printf.sprintf "%d %d %s | %s" ok after.anchor_advance
        (Fixture_lines.micros_since ~from:origin after.anchor_time)
        (note result)
  | _ -> failwith "reanchor: state stream blinks radius origin clock streams"

let () =
  Fixture_lines.check_op records "reanchor" reanchor;
  Table_test.finish ()
