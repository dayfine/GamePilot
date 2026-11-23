(** Each watcher's blink threshold during a blink recovery: estimated from its
    samples, estimated again when their count has moved by a quarter, and frozen
    for every watcher at the first solve so that blink numbering stops moving.

    Port of the threshold steps of [recover_state_from_blinks] in the fork's
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkRecovery.cpp] (R21:
    same order, same integer quarter). The C++'s -1 for "none yet" is [None];
    its per-watcher frozen values, all set at once, are one option. *)

type t

val start : watchers:int -> t

val thresholds :
  t -> Blink_extraction.match_sample list list -> t * float list option
(** Every watcher's threshold for this pass, in order: the frozen ones, or
    estimates. [None] at the first watcher whose threshold cannot be estimated
    yet (later watchers keep their old estimate, as the C++ stops there). *)

val freeze : t -> float list -> t
(** Freezes these thresholds unless some already are. *)

val frozen : t -> float list option
