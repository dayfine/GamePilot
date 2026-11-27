(** Recovers the Xorshift128 state from a Pokemon model's blinks: the seconds
    between two blinks give the top four bits of the roll's fraction, and 32 or
    more such readings make a linear system over GF(2) whose solution is the
    state.

    Port of the Pokemon half of
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateSolver.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source; R21: same reading
    order, same subsets, same messages); the NPC half is {!State_solver}. Where
    the C++ takes an optional [Logger] and logs a success, this port logs
    nothing. *)

val recommended_pokemon_blink_count : float -> int
(** How many intervals to time at the given timing tolerance (seconds) so that
    about 40 fall far enough inside their bucket; 1000 when the tolerance leaves
    almost none usable. The C++'s default tolerance is 0.1. *)

type request = {
  intervals : float list;
      (** Seconds between consecutive blinks; interval [c] is roll [c + 1]. *)
  tolerance_seconds : float;  (** The C++ default is 0.1. *)
  max_attempts : int;  (** The C++ default is 64. *)
}
(** [PokemonBlinkSolveRequest]. *)

type result = {
  success : bool;
  state : Xorshift128.state;
      (** The state before the first interval's roll; zero unless [success]. *)
  advances_to_last_interval : int;
  observations_used : int;
  observations_discarded : int;
  equations_used : int;
  null_space_dimension : int;
  attempts : int;
  weakest_margin_used : float;
  mistimed_intervals : int;
  worst_residual_seconds : float;
  failure_reason : string;
}
(** [PokemonBlinkSolveResult]. *)

val solve_state_from_pokemon_blinks : request -> result
(** Sorts the readings by their margin (most room first, index breaking ties)
    and solves from the confident ones (margin at least the tolerance, and never
    fewer than 32). If that fails it leaves out one reading at a time, weakest
    first, up to [max_attempts] subsets. A state is accepted when at most one
    interval in eight (at least two) is off by more than the tolerance. *)
