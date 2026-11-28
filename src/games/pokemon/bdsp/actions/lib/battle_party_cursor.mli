(** Tracks BDSP in-battle party menu order and per-Pokémon Fight cursor memory.

    In BDSP, switching a party slot into battle swaps that Pokémon with visual
    row 0 in the party menu, and the Fight submenu remembers each Pokémon's
    last-selected move slot across turns. *)

type t
(** Mutable tracker of BDSP party visual rows and last-selected move slots. *)

val create : party_size:int -> initial_active_slot:int -> t
(** Creates a tracker for [party_size] slots (1..[party_size]) with
    [initial_active_slot] active at visual row 0. *)

val active_slot : t -> int
(** The currently active 1-based logical party slot. *)

val swap_to : t -> int -> int
(** Records switching logical [slot] into battle, updating visual row 0 and
    returning the 0-based visual row [slot] occupied before the swap. *)

val last_move : t -> int
(** Last-used 1-based move slot for the currently active Pokémon (default 1). *)

val record_move : t -> int -> unit
(** Records that the currently active Pokémon selected 1-based [move_slot]. *)
