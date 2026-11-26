type state = { s0 : int; s1 : int; s2 : int; s3 : int }

let word_mask = 0xFFFF_FFFF
let word_bits = 32
let jump_threshold = 512

(* Shifts of one step forward, and of undoing it. *)
let forward_left = 11
let forward_right = 8
let s3_right = 19
let undo_fold_right = 16
let undo_fold_left = 22

let state_to_string { s0; s1; s2; s3 } =
  Printf.sprintf "[0x%08x, 0x%08x, 0x%08x, 0x%08x]" s0 s1 s2 s3

let high_word seed =
  Int64.to_int (Int64.shift_right_logical seed word_bits) land word_mask

let low_word seed = Int64.to_int seed land word_mask

let state_of_seed_pair seed0 seed1 =
  {
    s0 = high_word seed0;
    s1 = low_word seed0;
    s2 = high_word seed1;
    s3 = low_word seed1;
  }

let seed_of_words high low =
  Int64.logor
    (Int64.shift_left (Int64.of_int high) word_bits)
    (Int64.of_int low)

let state_to_seed_pair s = (seed_of_words s.s0 s.s1, seed_of_words s.s2 s.s3)

let state_to_vector s =
  let high, low = state_to_seed_pair s in
  { Gf2_matrix.high; low }

let state_of_vector (v : Gf2_matrix.vec) = state_of_seed_pair v.high v.low

type t = { mutable current : state }

let create state = { current = state }
let state t = t.current
let set_state t state = t.current <- state
let copy t = { current = t.current }
let shift_left_word x n = (x lsl n) land word_mask

let next t =
  let { s0; s1; s2; s3 } = t.current in
  let temp = s0 lxor shift_left_word s0 forward_left in
  let s3' = temp lxor (temp lsr forward_right) lxor s3 lxor (s3 lsr s3_right) in
  t.current <- { s0 = s1; s1 = s2; s2 = s3; s3 = s3' };
  s3'

let prev t =
  let { s0; s1; s2; s3 } = t.current in
  let temp = (s2 lsr s3_right) lxor s2 lxor s3 in
  let temp = temp lxor (temp lsr forward_right) in
  let temp = temp lxor (temp lsr undo_fold_right) in
  let temp = temp lxor shift_left_word temp forward_left in
  let temp = temp lxor shift_left_word temp undo_fold_left in
  t.current <- { s0 = temp; s1 = s0; s2 = s1; s3 = s2 }

(* The image of basis vector [column] under [step]. *)
let basis_image step column =
  let rng =
    create (state_of_vector (Gf2_matrix.set Gf2_matrix.zero column true))
  in
  step rng;
  state_to_vector rng.current

(* Row [row] of the matrix whose columns are [images]. *)
let matrix_row images row =
  let set_bit acc column =
    if Gf2_matrix.get images.(column) row then Gf2_matrix.set acc column true
    else acc
  in
  Seq.fold_left set_bit Gf2_matrix.zero (Seq.init Gf2_matrix.dimension Fun.id)

(* The matrix whose column [c] is the image of basis vector [c] under [step]. *)
let step_matrix step =
  let images = Array.init Gf2_matrix.dimension (basis_image step) in
  Gf2_matrix.init (matrix_row images)

let transition_matrix = step_matrix (fun rng -> ignore (next rng))
let inverse_transition_matrix = step_matrix prev
let count_bits = 63

(* T^(2^k) for every k that fits in a count. *)
let powers_of_two =
  lazy
    (let table = Array.make count_bits transition_matrix in
     for c = 1 to count_bits - 1 do
       table.(c) <- Gf2_matrix.mul table.(c - 1) table.(c - 1)
     done;
     table)

let transition_power count =
  let powers = Lazy.force powers_of_two in
  let rec go ret count bit =
    if count = 0 then ret
    else
      let ret =
        if count land 1 <> 0 then Gf2_matrix.mul powers.(bit) ret else ret
      in
      go ret (count lsr 1) (bit + 1)
  in
  go Gf2_matrix.identity count 0

let jump t matrix =
  t.current <-
    state_of_vector (Gf2_matrix.apply matrix (state_to_vector t.current))

let advance t count =
  if count < jump_threshold then
    for _ = 1 to count do
      ignore (next t)
    done
  else jump t (transition_power count)

let rewind t count =
  if count < jump_threshold then
    for _ = 1 to count do
      prev t
    done
  else jump t (Gf2_matrix.pow inverse_transition_matrix count)

let gen_modulus = 0xFFFF_FFFF
let gen_offset = 0x8000_0000
let bdsp_gen_transform raw = ((raw mod gen_modulus) + gen_offset) land word_mask

module Window = struct
  type window = {
    rng : t;
    buffer : int array;
    mutable head : int;
    mutable index : int;
  }

  let create ~size_bits generator =
    let size = 1 lsl size_bits in
    let rng = copy generator in
    let buffer = Array.init size (fun _ -> next rng) in
    { rng; buffer; head = 0; index = 0 }

  let slot w at = at land (Array.length w.buffer - 1)

  let next_raw w =
    let value = w.buffer.(slot w w.index) in
    w.index <- w.index + 1;
    value

  let next_gen w = bdsp_gen_transform (next_raw w)
  let next_raw_modulo w modulo = next_raw w mod modulo
  let next_gen_modulo w modulo = next_gen w mod modulo
  let skip w count = w.index <- w.index + count

  let advance_state w =
    w.buffer.(slot w w.head) <- next w.rng;
    w.head <- w.head + 1;
    w.index <- w.head

  let reset_index w = w.index <- w.head
end
