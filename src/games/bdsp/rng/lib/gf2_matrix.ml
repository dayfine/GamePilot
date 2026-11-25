type vec = { high : int64; low : int64 }

let dimension = 128
let bits_per_word = 64
let last_bit_of_high = bits_per_word - 1
let last_bit = dimension - 1
let zero = { high = Int64.zero; low = Int64.zero }

(* The word holding [index] and the bit's position in it, counted from the
   least significant bit. *)
let word_bit vec index =
  if index < bits_per_word then (vec.high, last_bit_of_high - index)
  else (vec.low, last_bit - index)

let get vec index =
  let word, position = word_bit vec index in
  Int64.logand (Int64.shift_right_logical word position) Int64.one <> Int64.zero

let set vec index value =
  let word, position = word_bit vec index in
  let mask = Int64.shift_left Int64.one position in
  let word =
    if value then Int64.logor word mask
    else Int64.logand word (Int64.lognot mask)
  in
  if index < bits_per_word then { vec with high = word }
  else { vec with low = word }

let xor a b =
  { high = Int64.logxor a.high b.high; low = Int64.logxor a.low b.low }

let rec popcount_parity word parity =
  if word = Int64.zero then parity
  else
    (* Clearing the lowest set bit, as [bits &= bits - 1]. *)
    popcount_parity (Int64.logand word (Int64.pred word)) (not parity)

let dot a b =
  let parity = popcount_parity (Int64.logand a.high b.high) false in
  popcount_parity (Int64.logand a.low b.low) parity

type t = vec array

let init row = Array.init dimension row
let row m index = m.(index)
let identity = Array.init dimension (fun c -> set zero c true)
let equal a b = Array.for_all2 (fun x y -> x = y) a b

let mul a b =
  let product_row left =
    let accumulator = ref zero in
    for k = 0 to last_bit do
      if get left k then accumulator := xor !accumulator b.(k)
    done;
    !accumulator
  in
  Array.map product_row a

let apply m column =
  let ret = ref zero in
  for c = 0 to last_bit do
    ret := set !ret c (dot m.(c) column)
  done;
  !ret

let pow m exponent =
  let rec go ret base exponent =
    if exponent = 0 then ret
    else
      let ret = if exponent land 1 <> 0 then mul ret base else ret in
      let exponent = exponent lsr 1 in
      go ret (if exponent <> 0 then mul base base else base) exponent
  in
  go identity m exponent
