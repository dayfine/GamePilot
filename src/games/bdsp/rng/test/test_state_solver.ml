(* The GF(2) solver and both state solvers against the C++'s golden vectors
   (fixtures/state_solver.txt). Each line names how its system or samples were
   drawn from a known state; this test draws them the same way. *)

open Bdsp_rng

let records = Fixture_lines.read "fixtures/state_solver.txt"
let hex = Fixture_lines.hex
let float17 = Fixture_lines.float17

let state_text (s : Xorshift128.state) =
  String.concat " " (List.map Fixture_lines.hex32 [ s.s0; s.s1; s.s2; s.s3 ])

(* A state from the first four inputs, and the inputs after them. *)
let state_and_rest = function
  | s0 :: s1 :: s2 :: s3 :: rest ->
      ({ Xorshift128.s0 = hex s0; s1 = hex s1; s2 = hex s2; s3 = hex s3 }, rest)
  | inputs -> failwith ("not a state: " ^ String.concat " " inputs)

let word rng high =
  let low = Int64.of_int (Xorshift128.next rng) in
  Int64.logor (Int64.shift_left (Int64.of_int high) 32) low

let random_vector rng =
  let high = word rng (Xorshift128.next rng) in
  let low = word rng (Xorshift128.next rng) in
  { Gf2_matrix.high; low }

let vector_text (v : Gf2_matrix.vec) =
  Printf.sprintf "%016Lx%016Lx" v.high v.low

let vector_of_text text =
  let half = String.length text / 2 in
  let word at = Int64.of_string ("0x" ^ String.sub text at half) in
  { Gf2_matrix.high = word 0; low = word half }

(* Rows drawn after a secret solution and masked; constants are the rows times
   the secret, the last one flipped when asked. *)
let gf2_system state height mask flip_last =
  let rng = Xorshift128.create state in
  let secret = random_vector rng in
  let rows =
    Array.init height (fun _ ->
        let row = random_vector rng in
        {
          Gf2_matrix.high = Int64.logand row.high mask.Gf2_matrix.high;
          low = Int64.logand row.low mask.low;
        })
  in
  let constants =
    Array.mapi
      (fun c row -> Gf2_matrix.dot row secret <> (flip_last && c + 1 = height))
      rows
  in
  (rows, constants)

let gf2_solve inputs =
  match state_and_rest inputs with
  | state, [ height; mask; flip ] ->
      let rows, constants =
        gf2_system state (int_of_string height) (vector_of_text mask)
          (flip = "1")
      in
      let solved = Gf2_matrix.solve rows constants in
      String.concat " "
        ((if solved.consistent then "1" else "0")
        :: vector_text solved.particular
        :: string_of_int (Array.length solved.null_space_basis)
        :: List.map vector_text (Array.to_list solved.null_space_basis))
  | _ -> failwith "gf2_solve: state height mask flip"

let reason text = "reason=" ^ text

(* Watched rolls every [stride] advances; see generate_golden.cpp. *)
let npc_samples state ~count ~stride ~types ~flip ~repeat =
  let rng = Xorshift128.create state in
  List.init count (fun c ->
      if c <> 0 then
        for _ = 2 to stride do
          ignore (Xorshift128.next rng)
        done;
      let roll = Xorshift128.next rng in
      let blinked = Blink_model.npc_blinks roll <> (c = flip) in
      let typed = types = "all" || (types = "even" && c mod 2 = 0) in
      let blink_type =
        if blinked && typed then Some (Blink_model.npc_blink_type roll)
        else None
      in
      List.init repeat (fun _ ->
          { State_solver.advance = c * stride; blinked; blink_type }))
  |> List.concat

let solve_npc inputs =
  match state_and_rest inputs with
  | state, [ count; stride; types; flip; repeat ] ->
      let r =
        State_solver.solve_state_from_samples
          (npc_samples state ~count:(int_of_string count)
             ~stride:(int_of_string stride) ~types ~flip:(int_of_string flip)
             ~repeat:(int_of_string repeat))
      in
      Printf.sprintf "%d %s %d %d %d %s" (Bool.to_int r.success)
        (state_text r.state) r.advances_to_last_blink r.equations_used
        r.null_space_dimension (reason r.failure_reason)
  | _ -> failwith "solve_npc: state count stride types flip repeat"

let recommended inputs =
  string_of_int
    (Pokemon_blink_solver.recommended_pokemon_blink_count
       (float_of_string (List.hd inputs)))

let solve_pokemon = function
  | tolerance :: attempts :: _count :: intervals ->
      let r =
        Pokemon_blink_solver.solve_state_from_pokemon_blinks
          {
            intervals = List.map float_of_string intervals;
            tolerance_seconds = float_of_string tolerance;
            max_attempts = int_of_string attempts;
          }
      in
      Printf.sprintf "%d %s %d %d %d %d %d %d %s %d %s %s"
        (Bool.to_int r.success) (state_text r.state) r.advances_to_last_interval
        r.observations_used r.observations_discarded r.equations_used
        r.null_space_dimension r.attempts
        (float17 r.weakest_margin_used)
        r.mistimed_intervals
        (float17 r.worst_residual_seconds)
        (reason r.failure_reason)
  | _ -> failwith "solve_pokemon: tolerance attempts count intervals"

let raises_invalid_argument f =
  match f () with
  | _ -> Error "no Invalid_argument"
  | exception Invalid_argument _ -> Ok ()

let sample advance = { State_solver.advance; blinked = true; blink_type = None }

let () =
  let check = Fixture_lines.check_op records in
  check "gf2_solve" gf2_solve;
  check "solve_npc" solve_npc;
  check "recommended" recommended;
  check "solve_pokemon" solve_pokemon;
  Case_table.report "gf2_solve: rows and constants must pair up"
    (raises_invalid_argument (fun () ->
         Gf2_matrix.solve [| Gf2_matrix.zero |] [||]));
  Case_table.report "solve_npc: samples must start at advance zero"
    (raises_invalid_argument (fun () ->
         State_solver.solve_state_from_samples [ sample 1 ]));
  Case_table.report "solve_npc: samples must be sorted"
    (raises_invalid_argument (fun () ->
         State_solver.solve_state_from_samples [ sample 0; sample 5; sample 3 ]));
  Case_table.finish ()
