(* The advance clock against the C++'s golden vectors
   (fixtures/advance_clock.txt). Times on the lines are microseconds. *)

open Bdsp_rng

let records = Fixture_lines.read "fixtures/advance_clock.txt"
let seconds_of_us text = float_of_string text /. 1e6

(* The clock from the first four inputs, and the input after them. *)
let clock = function
  | anchor_us :: anchor_advance :: tick :: npcs :: [ query ] ->
      ( ({
           anchor_time = seconds_of_us anchor_us;
           anchor_advance = int_of_string anchor_advance;
           tick_seconds = float_of_string tick;
           npcs = int_of_string npcs;
         }
          : Advance_clock.t),
        query )
  | inputs -> failwith ("not a clock and a query: " ^ String.concat " " inputs)

let advance_at inputs =
  let clock, time_us = clock inputs in
  string_of_int (Advance_clock.advance_at clock (seconds_of_us time_us))

let time_of_advance inputs =
  let clock, advance = clock inputs in
  let advance = int_of_string advance in
  let since_zero = Fixture_lines.micros_since ~from:0.0 in
  since_zero (Advance_clock.time_of_advance clock advance)
  ^ " "
  ^ since_zero (Advance_clock.middle_of_advance clock advance)

let () =
  Fixture_lines.check_op records "advance_at" advance_at;
  Fixture_lines.check_op records "time_of_advance" time_of_advance;
  Table_test.finish ()
