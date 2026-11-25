(* Port of increment_internal_rng_state (Pokemon/Pokemon_AdvRng.cpp); jump is
   ours (see lcg.mli). *)

let multiplier = 0x41c64e6d
let increment = 0x6073
let mask32 = 0xffffffff
let next state = ((state * multiplier) + increment) land mask32

(* Steps as affine maps s -> a * s + c: applying (a1, c1) then (a2, c2) is
   (a2 * a1, a2 * c1 + c2). [jump] squares the one-step map per bit of n. *)
let compose (a1, c1) (a2, c2) =
  (a2 * a1 land mask32, ((a2 * c1) + c2) land mask32)

let jump state n =
  let rec go acc step n =
    if n = 0 then acc
    else
      let acc = if n land 1 = 1 then compose acc step else acc in
      go acc (compose step step) (n lsr 1)
  in
  let a, c = go (1, 0) (multiplier, increment) n in
  ((a * state) + c) land mask32
