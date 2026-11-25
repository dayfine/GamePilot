(** Checks the states a GF(2) solution leaves open: the particular solution plus
    every XOR-combination of its null space basis.

    Port of [count_verified_candidates] and [MAX_ENUMERATED_BITS] from the
    fork's [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateSolver.cpp]
    (R21: same candidate order, same early stop), shared by {!State_solver} and
    {!Pokemon_blink_solver}. *)

val max_enumerated_bits : int
(** 12: the most unknown bits the solvers check one by one. *)

val count_verified :
  Gf2_matrix.solution ->
  (Xorshift128.state -> bool) ->
  int * Xorshift128.state option
(** Runs the verifier on each candidate in mask order (bit [b] of the mask adds
    basis vector [b]) and stops after the second survivor, which already means
    the answer is not pinned down. Returns the survivor count (0, 1 or 2) and
    the last survivor. *)
