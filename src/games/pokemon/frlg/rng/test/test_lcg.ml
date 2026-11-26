(* Lcg and Rng_state against the C++'s golden vectors (fixtures/lcg.txt). *)

open Frlg_rng

let records = Fixture_lines.read "fixtures/lcg.txt"

let next = function
  | [ state; count ] ->
      let rec go s n acc =
        if n = 0 then List.rev acc
        else
          let s = Lcg.next s in
          go s (n - 1) (Fixture_lines.hex32 s :: acc)
      in
      String.concat " " (go (Fixture_lines.hex state) (int_of_string count) [])
  | _ -> failwith "next: state count"

let jump = function
  | [ state; n ] ->
      Fixture_lines.hex32 (Lcg.jump (Fixture_lines.hex state) (int_of_string n))
  | _ -> failwith "jump: state n"

let state = function
  | [ seed; advance ] ->
      let s =
        Rng_state.of_seed ~seed:(Fixture_lines.hex seed)
          ~advance:(int_of_string advance) Method1
      in
      String.concat " "
        (List.map Fixture_lines.hex32 [ s.s0; s.s1; s.s2; s.s3; s.s4; s.s5 ])
  | _ -> failwith "state: seed advance"

(* Rng_state.next agrees with jumping straight to the next advance. *)
let next_window () =
  let start = Rng_state.of_seed ~seed:0x5a0e ~advance:1000 Method2 in
  let stepped = Rng_state.next (Rng_state.next start) in
  if stepped = Rng_state.of_seed ~seed:0x5a0e ~advance:1002 Method2 then Ok ()
  else Error "two nexts differ from of_seed at advance + 2"

let () =
  let check = Fixture_lines.check_op records in
  check "next" next;
  check "jump" jump;
  check "state" state;
  Table_test.report "Rng_state.next" (next_window ());
  Table_test.finish ()
