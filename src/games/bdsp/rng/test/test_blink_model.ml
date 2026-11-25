(* The blink model against the C++'s golden vectors (fixtures/blink_model.txt).
   Floats are compared as "%.17g" text, so a match is bit for bit. *)

open Bdsp_rng
open Blink_model

let records = Fixture_lines.read "fixtures/blink_model.txt"
let hex = Fixture_lines.hex
let float17 = Fixture_lines.float17

let range_float_line = function
  | [ roll; minimum; maximum ] ->
      float17
        (range_float (hex roll) ~minimum:(float_of_string minimum)
           ~maximum:(float_of_string maximum))
  | _ -> failwith "range_float: roll min max"

let interval inputs = float17 (pokemon_blink_interval (hex (List.hd inputs)))
let interval_input inputs = float_of_string (List.hd inputs)

let fraction inputs =
  match pokemon_blink_fraction (interval_input inputs) with
  | Some fraction -> Printf.sprintf "1 %d" fraction
  | None -> "0 0"

let bucket inputs =
  match pokemon_blink_bucket_with_margin (interval_input inputs) with
  | Some (bucket, margin) -> Printf.sprintf "1 %d %s" bucket (float17 margin)
  | None -> "0 0 0"

let tick_char tick =
  match (tick.blinked, tick.blink_type) with
  | false, _ -> '.'
  | true, Single -> 'S'
  | true, Double -> 'D'

let ticks_line = function
  | [ s0; s1; s2; s3; ticks; npcs; slot ] ->
      let state =
        { Xorshift128.s0 = hex s0; s1 = hex s1; s2 = hex s2; s3 = hex s3 }
      in
      generate_blink_ticks state ~ticks:(int_of_string ticks)
        ~npcs:(int_of_string npcs) ~slot:(int_of_string slot)
      |> Result.get_ok |> List.map tick_char |> List.to_seq |> String.of_seq
  | _ -> failwith "ticks: state ticks npcs slot"

let rejected = function Ok _ -> Error "accepted" | Error _ -> Ok ()
let zero_state = { Xorshift128.s0 = 1; s1 = 0; s2 = 0; s3 = 0 }

let () =
  let check = Fixture_lines.check_op records in
  check "range_float" range_float_line;
  check "interval" interval;
  check "fraction" fraction;
  check "bucket" bucket;
  check "ticks" ticks_line;
  Table_test.report "ticks: no NPCs is rejected"
    (rejected (generate_blink_ticks zero_state ~ticks:1 ~npcs:0 ~slot:0));
  Table_test.report "ticks: a slot past the NPCs is rejected"
    (rejected (generate_blink_ticks zero_state ~ticks:1 ~npcs:2 ~slot:2));
  Table_test.finish ()
