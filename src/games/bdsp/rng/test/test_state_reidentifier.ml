(* The state reidentifier against the C++'s golden vectors
   (fixtures/reidentifier.txt): blinks watched from a known state at a known
   offset, then altered or cut short. *)

open Bdsp_rng

let records = Fixture_lines.read "fixtures/reidentifier.txt"
let hex = Fixture_lines.hex

let blink_type = function
  | "S" -> Blink_model.Single
  | "D" -> Double
  | text -> failwith ("not a blink type: " ^ text)

let observation kind values =
  match kind with
  | "intervals" -> State_reidentifier.Intervals (List.map int_of_string values)
  | "types" -> Types (List.map blink_type values)
  | _ -> failwith ("not an observation: " ^ kind)

let reidentify = function
  | s0 :: s1 :: s2 :: s3 :: search_min :: search_max :: npcs :: kind :: _count
    :: values ->
      let r =
        State_reidentifier.reidentify_advances
          {
            base_state = { s0 = hex s0; s1 = hex s1; s2 = hex s2; s3 = hex s3 };
            search_min = int_of_string search_min;
            search_max = int_of_string search_max;
            npcs = int_of_string npcs;
            observation = observation kind values;
          }
      in
      Printf.sprintf "%d %d %d %d %d reason=%s" (Bool.to_int r.success)
        (Bool.to_int r.ambiguous) r.match_count r.advances_to_first_blink
        r.advances_to_last_blink r.failure_reason
  | _ -> failwith "reidentify: state min max npcs kind count values"

let () =
  Fixture_lines.check_op records "reidentify" reidentify;
  Case_table.finish ()
