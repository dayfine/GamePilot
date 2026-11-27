(** Mixed [1PK] (1 player + 1 3D Pokemon model) state re-identification.

    Given a known {!Xorshift128.state} (for instance from the Munchlax intro
    seed finder) and a short sequence of observed player blinks inside a chamber
    with one spawned 3D Pokemon model, finds the exact advance of the first and
    last observed player blinks and bounds the Pokemon model's next blink time.

    Implements the [1PK] re-identification design in
    [docs/design/BDSP-Static-Legendary-RNG.md] (§1.3, carried over from
    [https://github.com/dayfine/Arduino-Source/pull/782]), extending
    {!State_reidentifier} (ported from upstream
    [https://github.com/PokemonAutomation/Arduino-Source]
    [SerialPrograms/Source/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateReidentifier.{h,cpp}]).
    Handles player tick period drift (fitting the period from the blinks when
    omitted), arbitrary initial Pokemon blink phases, order-swap branching when
    a player tick and Pokemon blink may swap, and frame-drop uncertainty
    (optional blink types and unknown player ticks). *)

type player_blink = {
  seconds : float;  (** Seconds elapsed (first blink is the origin). *)
  blink_type : Blink_model.blink_type option;
      (** [None] when a frame stall made single vs. double uncertain. *)
}
(** One observed player blink relative to the start of the observation window.
*)

type request = {
  base_state : Xorshift128.state;  (** Known seed before [search_min]. *)
  search_min : int;  (** Lowest candidate advance for the first blink. *)
  search_max : int;  (** Highest candidate advance for the first blink. *)
  blinks : player_blink list;  (** Observed player blinks in time order. *)
  unknown_ticks : int list;
      (** Player tick indices (relative to the first blink at tick 0) that fell
          inside capture gaps and cannot be assumed quiet. *)
  tick_seconds : float option;
      (** Player tick period in seconds; when [None], fitted from [blinks] or
          defaulted to {!Blink_model.npc_tick_seconds}. *)
  order_swap_tolerance : float;
      (** Half-width tolerance in seconds around each player tick when deciding
          whether a player tick and a Pokemon blink may swap order. *)
}
(** Inputs to {!reidentify}. *)

val default_order_swap_tolerance : float
(** 0.08: default order-swap timing tolerance in seconds. *)

type result = {
  success : bool;  (** True only when a unique [(first, last)] match exists. *)
  ambiguous : bool;  (** True when two or more positions fit the blinks. *)
  match_count : int;  (** Matches found, capped at 8. *)
  fitted_tick_seconds : float;
      (** Player tick period used for the search, in seconds. *)
  advances_to_first_blink : int;
      (** Advance of the first observed player blink, when [success]. *)
  advances_to_last_blink : int;
      (** Advance of the last observed player blink, when [success]. *)
  next_pokemon_blink_min_seconds : float;
      (** Lower bound (seconds after the last player blink) on the Pokemon
          model's next blink, when [success]. *)
  next_pokemon_blink_max_seconds : float;
      (** Upper bound (seconds after the last player blink) on the Pokemon
          model's next blink, when [success]. *)
  failure_reason : string;  (** Human-readable reason when [not success]. *)
}
(** Result of {!reidentify}. *)

val reidentify : request -> result
(** Searches [search_min..search_max] for the unique advance where [1] periodic
    player and [1] aperiodic Pokemon model reproduce [blinks] under any initial
    Pokemon blink phase in 0 to 12.285 seconds. *)
