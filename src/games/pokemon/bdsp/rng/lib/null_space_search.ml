let max_enumerated_bits = 12

let candidate (solved : Gf2_matrix.solution) mask =
  let vector = ref solved.particular in
  Array.iteri
    (fun bit basis ->
      if (mask lsr bit) land 1 <> 0 then vector := Gf2_matrix.xor !vector basis)
    solved.null_space_basis;
  Xorshift128.state_of_vector !vector

let count_verified (solved : Gf2_matrix.solution) verifier =
  let combinations = 1 lsl Array.length solved.null_space_basis in
  let rec go mask verified winner =
    if mask >= combinations || verified > 1 then (verified, winner)
    else
      let state = candidate solved mask in
      if verifier state then go (mask + 1) (verified + 1) (Some state)
      else go (mask + 1) verified winner
  in
  go 0 0 None
