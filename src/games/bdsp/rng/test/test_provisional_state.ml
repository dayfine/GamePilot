(* The provisional-state rule against the C++'s golden vectors
   (fixtures/blink_recovery.txt, "provisional" lines): solves fed in order,
   including the misread that stops a held state solving (fork #816). *)

open Bdsp_rng

let records = Fixture_lines.read "fixtures/blink_recovery.txt"

(* "A44": state A solved from 44 rolls; "-": a failed solve. *)
let solve text =
  if text = "-" then (None, 0)
  else
    let base = 4 * (Char.code text.[0] - Char.code 'A') in
    ( Some
        ({ s0 = base + 1; s1 = base + 2; s2 = base + 3; s3 = base + 4 }
          : Xorshift128.state),
      int_of_string (String.sub text 1 (String.length text - 1)) )

let step_text : Provisional_state.step -> string = function
  | Keep_collecting -> "keep"
  | Provisional -> "provisional"
  | Changed -> "changed"
  | Dropped -> "dropped"
  | Confirmed -> "confirmed"

let provisional = function
  | confirmation_events :: _count :: solves ->
      let confirmation_events = int_of_string confirmation_events in
      let final, steps =
        List.fold_left_map
          (fun provisional text ->
            let state, events = solve text in
            Provisional_state.update provisional state ~events
              ~confirmation_events)
          Provisional_state.empty solves
      in
      let held, s0, events =
        match final.held with
        | Some held -> (1, held.state.s0, held.events)
        | None -> (0, 0, 0)
      in
      Printf.sprintf "%s | %d %d %d %d"
        (String.concat " " (List.map step_text steps))
        held s0 events final.failed_solves
  | _ -> failwith "provisional: confirmation count solves"

let () =
  Fixture_lines.check_op records "provisional" provisional;
  Case_table.finish ()
