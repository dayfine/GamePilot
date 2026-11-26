(** Recovers the Xorshift128 state from an NPC's blinks. Each blink pins the low
    bits of one roll; enough of them make a linear system over GF(2) whose
    solution is the state, and the few states it leaves open
    ({!Null_space_search}) are checked against every watched roll.

    Port of the NPC half of the fork's
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateSolver.{h,cpp}] (R21:
    same equations, same order, same messages); the Pokemon half is
    {!Pokemon_blink_solver}. Where the C++ takes an optional [Logger] and logs a
    success, this port logs nothing: the caller has the whole result. Advances
    are OCaml [int]s (the C++ [uint64_t]). Precondition failures return [Error]
    where the C++ throws [InternalProgramError]. *)

type blink_sample = {
  advance : int;  (** Rolls since the first watched one. *)
  blinked : bool;
  blink_type : Blink_model.blink_type option;
      (** [None] when the detector could not tell single from double. *)
}
(** [BlinkSample]: one watched NPC roll. *)

type blink_solve_result = {
  success : bool;
  state : Xorshift128.state;
      (** The state before the roll at advance 0; all zero unless [success]. *)
  advances_to_last_blink : int;
  equations_used : int;
  null_space_dimension : int;
  failure_reason : string;
}
(** [BlinkSolveResult]. *)

val solve_state_from_samples :
  blink_sample list -> (blink_solve_result, string) result
(** Solves from watched NPC rolls, sorted by advance and starting at advance 0
    (else [Error]: a bug in the caller, not a failed solve). Each blink gives
    three equations (bits 3-1 are zero) and a fourth when its type is known.
    Fails (with a reason) below 128 equations, on contradictions, with more than
    12 unknown bits left, or when not exactly one candidate reproduces every
    sample. *)
