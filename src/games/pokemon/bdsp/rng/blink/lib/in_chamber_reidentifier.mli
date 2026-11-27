(** In-chamber [1PK] (1 player + 1 spawned 3D Pokemon model) state
    re-identification from player eye blinks.

    Given a boot {!Bdsp_rng.Xorshift128.state} (such as the seed recovered by
    {!Munchlax_seed_finder}) and a player eye ROI/template, subscribes to
    {!Bdsp_readers.Eye_blink_reader.probes} with [delivery = Every], drains
    {!Effects.take_gaps} on every poll (marking dropped ticks in [unknown_ticks]
    and uncertain single/double blinks as [blink_type = None]), renews the input
    lease silently via {!Effects.renew_lease} every ~30 s, and calls
    {!Bdsp_rng.State_reidentifier.reidentify_with_pokemon_models} until a unique
    advance anchor is locked.

    Implements the [1PK] in-chamber workflow from
    [docs/design/BDSP-Static-Legendary-RNG.md] (§1.3,
    https://github.com/dayfine/Arduino-Source/pull/782), extending
    [SerialPrograms/Source/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateReidentifier.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source). *)

type search_bounds = {
  search_min : int;  (** Lowest candidate advance for the first blink. *)
  search_max : int;  (** Highest candidate advance for the first blink. *)
  min_blinks : int;  (** Minimum player blinks before attempting re-ID. *)
  max_blinks : int;  (** Maximum player blinks before giving up. *)
  tick_seconds : float option;
      (** Known player tick period, or [None] to fit from observed blinks. *)
  order_swap_tolerance : float;
      (** Half-width tolerance in seconds for player/Pokemon order swaps. *)
}
(** Search window and blink-count bounds for [1PK] re-identification. *)

val default_bounds : search_bounds
(** Default bounds: [[0, 40000]], 8 to 24 blinks, auto-fitted tick period, and
    {!Bdsp_rng.Mixed_reidentifier.default_order_swap_tolerance}. *)

type config = {
  picture : Wire.box;  (** Game picture viewport for probe clipping. *)
  target : Bdsp_readers.Eye_blink_reader.target;
      (** Player eye-blink probe target. *)
  base_state : Bdsp_rng.Xorshift128.state;
      (** Known boot seed before [bounds.search_min]. *)
  bounds : search_bounds;  (** Advance search range and blink limits. *)
  threshold : float;  (** Blink-depth threshold in [(0, 1)] (default 0.25). *)
  timeout_seconds : float;
      (** Maximum wall-clock wait before giving up (default 300.0 s). *)
  lease_renew_seconds : float;
      (** Interval between silent {!Effects.renew_lease} calls (default 30.0 s).
      *)
}
(** Configuration for {!run}. *)

val default_config :
  picture:Wire.box ->
  target:Bdsp_readers.Eye_blink_reader.target ->
  base_state:Bdsp_rng.Xorshift128.state ->
  config
(** Default in-chamber [1PK] re-identification config with {!default_bounds},
    0.25 depth threshold, 300 s timeout, and 30 s lease renewal. *)

type anchor = {
  base_state : Bdsp_rng.Xorshift128.state;
      (** Boot seed that advances are measured from. *)
  anchor_time_ms : float;
      (** Daemon clock timestamp in ms of the last observed player blink. *)
  advances_to_first_blink : int;
      (** Advance index of the first observed player blink. *)
  advances_to_last_blink : int;
      (** Advance index of the last observed player blink. *)
  next_pokemon_blink_min_seconds : float;
      (** Lower bound (seconds after [anchor_time_ms]) on the Pokemon model's
          next blink. *)
  next_pokemon_blink_max_seconds : float;
      (** Upper bound (seconds after [anchor_time_ms]) on the Pokemon model's
          next blink. *)
  fitted_tick_seconds : float;
      (** Player tick period in seconds locked by the re-identifier. *)
  gaps : Bdsp_rng.Blink_extraction.frame_gap list;
      (** Capture gaps observed during re-identification (in seconds from the
          first sample). *)
}
(** Locked [1PK] RNG anchor returned by {!run}. *)

val run : config -> (anchor, string) result
(** Watches player blinks in the chamber until a unique [1PK] {!anchor} is
    locked, or returns [Error] on timeout, [max_blinks] exhaustion, or missing
    probe. *)
