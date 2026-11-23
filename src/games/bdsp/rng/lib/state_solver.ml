open Blink_model

type blink_sample = {
  advance : int;
  blinked : bool;
  blink_type : blink_type option;
}

type blink_solve_result = {
  success : bool;
  state : Xorshift128.state;
  advances_to_last_blink : int;
  equations_used : int;
  null_space_dimension : int;
  failure_reason : string;
}

(* Rows of bits 3, 2, 1 and 0, which is what an NPC blink reveals. *)
let blink_bit_row_first = 124
let blink_zero_bits = 3
let blink_type_row = blink_bit_row_first + blink_zero_bits
let unknowns = Gf2_matrix.dimension
let zero_state = { Xorshift128.s0 = 0; s1 = 0; s2 = 0; s3 = 0 }

(* One watched roll against what was seen there. *)
let check_roll sample roll =
  let blinked = npc_blinks roll in
  let where = string_of_int sample.advance in
  let type_differs =
    match sample.blink_type with
    | Some seen -> blinked && npc_blink_type roll <> seen
    | None -> false
  in
  if blinked <> sample.blinked then
    Error
      (if blinked then
         "Recovered state blinks at advance " ^ where
         ^ ", where nothing was seen."
       else "Recovered state does not blink at advance " ^ where ^ ".")
  else if type_differs then
    Error
      ("Recovered state disagrees with the blink type at advance " ^ where ^ ".")
  else Ok ()

(* Double checks the observations against a candidate state. *)
let verify_samples state samples =
  let rng = Xorshift128.create state in
  let at = ref 0 in
  let check sample =
    while !at < sample.advance do
      ignore (Xorshift128.next rng);
      incr at
    done;
    incr at;
    check_roll sample (Xorshift128.next rng)
  in
  List.fold_left
    (fun verdict sample -> Result.bind verdict (fun () -> check sample))
    (Ok ()) samples

(* A blink's equations, read off the transition to its roll: bits 3, 2 and 1
   are zero whenever a blink happens at all, and bit 0 is the single/double
   distinction, which the detector may not have. *)
let blink_equations transition sample =
  let zero_bit bit =
    (Gf2_matrix.row transition (blink_bit_row_first + bit), false)
  in
  let type_bit seen =
    (Gf2_matrix.row transition blink_type_row, seen = Double)
  in
  List.init blink_zero_bits zero_bit
  @ Option.to_list (Option.map type_bit sample.blink_type)

(* Each blink constrains the four low bits of one roll. Returns the equations,
   their constants and the number of blinks. *)
let npc_equations samples =
  let equations = ref [] in
  let transition = ref Xorshift128.transition_matrix in
  let at = ref 0 in
  let blinks = ref 0 in
  let take sample =
    if sample.advance < !at then
      invalid_arg
        "State_solver.solve_state_from_samples: samples are not sorted by \
         advance";
    if sample.blinked && sample.advance > !at then (
      transition :=
        Gf2_matrix.mul
          (Xorshift128.transition_power (sample.advance - !at))
          !transition;
      at := sample.advance);
    if sample.blinked then (
      incr blinks;
      equations :=
        List.rev_append (blink_equations !transition sample) !equations)
  in
  List.iter take samples;
  let rows, constants = List.split (List.rev !equations) in
  (Array.of_list rows, Array.of_list constants, !blinks)

let npc_failure ?(equations_used = 0) ?(null_space_dimension = 0) reason =
  {
    success = false;
    state = zero_state;
    advances_to_last_blink = 0;
    equations_used;
    null_space_dimension;
    failure_reason = reason;
  }

let last_blink_advance samples =
  List.fold_left
    (fun last sample -> if sample.blinked then sample.advance else last)
    0 samples

(* The candidates left by a consistent, small enough solution. *)
let pick_npc_state samples (solved : Gf2_matrix.solution) equations_used =
  let first_rejection = ref "" in
  let verifier state =
    match verify_samples state samples with
    | Ok () -> true
    | Error reason ->
        if !first_rejection = "" then first_rejection := reason;
        false
  in
  let null_space_dimension = Array.length solved.null_space_basis in
  let failure = npc_failure ~equations_used ~null_space_dimension in
  match Null_space_search.count_verified solved verifier with
  | 1, Some state ->
      {
        success = true;
        state;
        advances_to_last_blink = last_blink_advance samples;
        equations_used;
        null_space_dimension;
        failure_reason = "";
      }
  | 0, _ ->
      failure
        (if !first_rejection = "" then
           "No candidate state reproduces the observed blinks."
         else !first_rejection)
  | _ ->
      failure
        "More than one state reproduces the observed blinks. Collect more \
         blinks."

let solve_equations samples rows constants =
  let equations_used = Array.length rows in
  let solved = Gf2_matrix.solve rows constants in
  let null_space_dimension = Array.length solved.null_space_basis in
  let failure = npc_failure ~equations_used ~null_space_dimension in
  if not solved.consistent then
    failure
      "The observations contradict each other. A blink was probably missed or \
       invented."
  else if null_space_dimension > Null_space_search.max_enumerated_bits then
    failure
      (Printf.sprintf
         "The observations leave %d unknown bits, too many to resolve by \
          checking. Collect more blinks."
         null_space_dimension)
  else pick_npc_state samples solved equations_used

let solve_watched samples =
  let rows, constants, blinks = npc_equations samples in
  let equations_used = Array.length rows in
  if equations_used < unknowns then
    npc_failure ~equations_used
      (Printf.sprintf
         "Only %d equations from %d blinks. At least 128 are needed."
         equations_used blinks)
  else solve_equations samples rows constants

let solve_state_from_samples samples =
  match samples with
  | [] -> npc_failure "No rolls were watched."
  | first :: _ when first.advance <> 0 ->
      invalid_arg
        "State_solver.solve_state_from_samples: samples must start at advance \
         zero"
  | _ -> solve_watched samples
