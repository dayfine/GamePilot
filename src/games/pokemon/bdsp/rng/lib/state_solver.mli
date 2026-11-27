(** Recovers the Xorshift128 state from an NPC's blinks. Each blink pins the low
    bits of one roll; enough of them make a linear system over GF(2) whose
    solution is the state, and the few states it leaves open
    ({!Null_space_search}) are checked against every watched roll.

    Port of the NPC half of the fork's
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateSolver.{h,cpp}] (R21:
    same equations, same order, same messages), extended with W10's 3-state
    observation so capture gaps and stalls can be skipped cleanly without false
    rejections or inferred non-blinks; the Pokemon half is
    {!Pokemon_blink_solver}. Where the C++ takes an optional [Logger] and logs a
    success, this port logs nothing: the caller has the whole result. Advances
    are OCaml [int]s (the C++ [uint64_t]). Precondition failures return [Error]
    where the C++ throws [InternalProgramError]. *)

(** What the detector observed at one NPC tick. *)
type observation =
  | Blinked of Blink_model.blink_type option
      (** A blink occurred at this tick; [None] when the detector could not tell
          single from double (for instance after a frame stall during the
          double-blink window). *)
  | No_blink  (** The tick was watched cleanly and no blink occurred. *)
  | Unknown
      (** The tick fell inside a capture gap or stall; skipped by both equation
          building and candidate verification. *)

type blink_sample = {
  advance : int;  (** Rolls since the first watched one. *)
  observation : observation;  (** What was seen at this roll. *)
}
(** [BlinkSample]: one watched NPC roll. *)

type blink_solve_result = {
  success : bool;  (** Whether a unique state reproduced every sample. *)
  state : Xorshift128.state;
      (** The state before the roll at advance 0; all zero unless [success]. *)
  advances_to_last_blink : int;
      (** Highest advance with a {!Blinked} observation. *)
  equations_used : int;  (** Number of GF(2) equations built from blinks. *)
  null_space_dimension : int;
      (** Unknown bits left after Gaussian elimination. *)
  failure_reason : string;  (** Human-readable reason when [not success]. *)
}
(** [BlinkSolveResult]. *)

val solve_state_from_samples :
  blink_sample list -> (blink_solve_result, string) result
(** Solves from watched NPC rolls, sorted by advance and starting at advance 0
    (else [Error]: a bug in the caller, not a failed solve). Each {!Blinked}
    sample gives three equations (bits 3-1 are zero) and a fourth when its type
    is [Some _]. {!No_blink} samples are checked during verification; {!Unknown}
    samples are skipped by both equation building and verification. Fails (with
    a reason) below 128 equations, on contradictions, with more than 12 unknown
    bits left, or when not exactly one candidate reproduces every known sample.
*)
