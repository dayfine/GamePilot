(** Reads the generator's filter, method and IV text and prints results and
    search hits the way it does (see [golden/generate_golden.cpp]). *)

open Frlg_rng

val rng_method : string -> Rng_state.rng_method
(** ["m1"], ["m2"], ["m3"], ["m4"] or ["any"]. *)

val method_text : Rng_state.rng_method -> string
val flag : string -> bool
val seeds : string -> int list

val filters : string list -> Target_search.filters * Target_search.trainer
(** Method, nature, ability, gender, shiny (C++ enum numbers, the last being
    [Any]), six ["low-high"] IV ranges, the gender threshold and TID ^ SID. *)

val pokemon_text : Pokemon_generation.result -> string
(** PID, gender value, nature, ability and the six IVs. *)

val hits_text : Rng_state.t list -> string
