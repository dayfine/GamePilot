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

let is_zero vec = vec.high = Int64.zero && vec.low = Int64.zero

type solution = {
  consistent : bool;
  particular : vec;
  null_space_basis : vec array;
}

let no_pivot = -1

let swap array i j =
  let held = array.(i) in
  array.(i) <- array.(j);
  array.(j) <- held

let rec find_pivot rows column row =
  if row >= Array.length rows then None
  else if get rows.(row) column then Some row
  else find_pivot rows column (row + 1)

(* Clears [column] from every row but the pivot's. *)
let clear_column rows constants column pivot =
  Array.iteri
    (fun row coefficients ->
      if row <> pivot && get coefficients column then (
        rows.(row) <- xor coefficients rows.(pivot);
        constants.(row) <- constants.(row) <> constants.(pivot)))
    rows

(* Reduces the augmented system in place; [pivot_row.(c)] is the row that owns
   column [c] as its pivot, or [no_pivot]. *)
let eliminate rows constants =
  let pivot_row = Array.make dimension no_pivot in
  let next_row = ref 0 in
  let column = ref 0 in
  while !column < dimension && !next_row < Array.length rows do
    (match find_pivot rows !column !next_row with
    | None -> ()
    | Some pivot ->
        swap rows !next_row pivot;
        swap constants !next_row pivot;
        clear_column rows constants !column !next_row;
        pivot_row.(!column) <- !next_row;
        incr next_row);
    incr column
  done;
  pivot_row

let inconsistent =
  { consistent = false; particular = zero; null_space_basis = [||] }

(* Free variables are zero, so each pivot variable is just its constant. *)
let particular_solution pivot_row constants =
  let solution = ref zero in
  Array.iteri
    (fun column row ->
      if row <> no_pivot then solution := set !solution column constants.(row))
    pivot_row;
  !solution

(* The basis vector of free column [column]: itself, and every pivot column
   whose row has [column] set. *)
let basis_vector rows pivot_row column =
  let basis = ref (set zero column true) in
  Array.iteri
    (fun pivot_column row ->
      if row <> no_pivot && get rows.(row) column then
        basis := set !basis pivot_column true)
    pivot_row;
  !basis

let solve equations rhs =
  if Array.length equations <> Array.length rhs then
    invalid_arg "Gf2_matrix.solve: coefficient and constant counts differ";
  let rows = Array.copy equations in
  let constants = Array.copy rhs in
  let pivot_row = eliminate rows constants in
  (* An all-zero row with a nonzero constant makes the system unsolvable. *)
  if Array.exists2 (fun row constant -> is_zero row && constant) rows constants
  then inconsistent
  else
    let free_columns =
      List.filter
        (fun column -> pivot_row.(column) = no_pivot)
        (List.init dimension Fun.id)
    in
    {
      consistent = true;
      particular = particular_solution pivot_row constants;
      null_space_basis =
        Array.of_list (List.map (basis_vector rows pivot_row) free_columns);
    }
