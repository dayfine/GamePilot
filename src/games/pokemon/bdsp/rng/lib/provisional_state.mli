(** The provisional RNG state a blink recovery holds until a later solve, over
    more blinks, repeats it; and the rule that drops a held state whose solves
    keep failing (https://github.com/dayfine/Arduino-Source, PR #816).

    Port of [ProvisionalState] and [update_provisional] from
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkRecovery.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source; R21: same
    transitions). The C++'s [held] flag with a state and roll count beside it
    becomes an option. *)

type held = {
  state : Xorshift128.state;
  events : int;  (** Rolls it was solved from. *)
}

type t = { held : held option; failed_solves : int }
(** [ProvisionalState]. [failed_solves] counts failed solves in a row while a
    state is held. *)

val empty : t
(** No state held, no failed solves: where a recovery starts. *)

type step =
  | Keep_collecting
  | Provisional
  | Changed
  | Dropped
  | Confirmed  (** [ProvisionalStep]. *)

val update :
  t ->
  Xorshift128.state option ->
  events:int ->
  confirmation_events:int ->
  t * step
(** [update_provisional]: takes one solve over [events] rolls ([None] when it
    failed). A repeat of the held state confirms it; another state replaces it
    ([Changed]). A held state is dropped after [confirmation_events] failed
    solves in a row: while one is held the blink window stops sliding, so a
    misread blink among its rolls fails every later solve until the attempt
    gives up; dropping it lets the window slide past. *)
