(* Xorshift128 against the C++'s golden vectors (fixtures/xorshift128.txt). *)

open Bdsp_rng

let records = Fixture_lines.read "fixtures/xorshift128.txt"

let state_text (s : Xorshift128.state) =
  String.concat " " (List.map Fixture_lines.hex32 [ s.s0; s.s1; s.s2; s.s3 ])

(* A generator from the first four inputs, and the inputs after them. *)
let generator = function
  | s0 :: s1 :: s2 :: s3 :: rest ->
      let word = Fixture_lines.hex in
      ( Xorshift128.create
          { s0 = word s0; s1 = word s1; s2 = word s2; s3 = word s3 },
        rest )
  | inputs -> failwith ("not a state: " ^ String.concat " " inputs)

let count rest = int_of_string (List.hd rest)

let outputs inputs =
  let rng, rest = generator inputs in
  List.init (count rest) (fun _ -> Fixture_lines.hex32 (Xorshift128.next rng))
  |> String.concat " "

let after step inputs =
  let rng, rest = generator inputs in
  step rng (count rest);
  state_text (Xorshift128.state rng)

let one_by_one step rng n =
  for _ = 1 to n do
    step rng
  done

let seed_pair inputs =
  let rng, _ = generator inputs in
  let state = Xorshift128.state rng in
  let seed0, seed1 = Xorshift128.state_to_seed_pair state in
  let round_trip = Xorshift128.state_of_seed_pair seed0 seed1 in
  if round_trip <> state then "seed pair does not round-trip"
  else
    Printf.sprintf "%016Lx %016Lx %s" seed0 seed1
      (Xorshift128.state_to_string state)

let gen inputs =
  Fixture_lines.hex32
    (Xorshift128.bdsp_gen_transform (Fixture_lines.hex (List.hd inputs)))

let () =
  let check = Fixture_lines.check_op records in
  check "next" outputs;
  check "steps" (after (one_by_one (fun rng -> ignore (Xorshift128.next rng))));
  check "prevs" (after (one_by_one Xorshift128.prev));
  check "advance" (after Xorshift128.advance);
  check "rewind" (after Xorshift128.rewind);
  check "seed_pair" seed_pair;
  check "gen" gen;
  Table_test.finish ()
