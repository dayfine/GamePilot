(** Finds how far a known Xorshift128 state has advanced by matching a short run
    of NPC blinks against the rolls that follow it: either the ticks between
    blinks or the blinks' types (single or double).

    Port of
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateReidentifier.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source; R21: same scans, same
    match cap, same messages). The C++'s method enum and its two vectors become
    one variant, so there is no "unknown method" failure; where the C++ takes an
    optional [Logger] and logs a success, this port logs nothing. Advances are
    OCaml [int]s (the C++ [uint64_t]). *)

type observation =
  | Intervals of int list
      (** Ticks between consecutive blinks of one NPC
          ([ReidentifyMethod::Intervals]). *)
  | Types of Blink_model.blink_type list
      (** Consecutive blinks' types ([ReidentifyMethod::Types]). *)

type request = {
  base_state : Xorshift128.state;
  search_min : int;  (** The C++ default is 0. *)
  search_max : int;  (** The C++ default is 1000000. *)
  npcs : int;  (** Rolls per tick; the C++ default is 1. *)
  observation : observation;
}
(** [ReidentifyRequest]. *)

type result = {
  success : bool;
  ambiguous : bool;
  match_count : int;  (** Counting stops at 8 (between NPC phases for types). *)
  advances_to_first_blink : int;
  advances_to_last_blink : int;
  failure_reason : string;
}
(** [ReidentifyResult]. *)

val reidentify_advances : request -> result
(** Where in [search_min, search_max] the observed run starts. By intervals:
    every gap must match exactly, a blink at each end and none between. By
    types: the run of blinks on one NPC's rolls starting there must have the
    observed types; refused up front when fewer types than the range needs (one
    bit per blink). Succeeds only on exactly one match. *)
