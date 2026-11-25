(** The Xorshift128 generator BDSP draws all its rolls from, with jumps of any
    length through {!Gf2_matrix}, and the sliding window of outputs the static
    search reads.

    Port of the fork's [Pokemon/Pokemon_Xorshift128.{h,cpp}] (R21: same
    shifts, same order, same 512-step threshold for jumping by matrix).

    Every 32-bit word is an OCaml [int] in [0, 2^32): results of left shifts
    and of the BDSP output transform are masked back to 32 bits, so the
    arithmetic is exact unsigned 32-bit as in the C++. *)

type state = { s0 : int; s1 : int; s2 : int; s3 : int }
(** [Xorshift128State]: four 32-bit words. *)

val state_to_string : state -> string
(** ["[0x0000000a, 0x...,  0x..., 0x...]"], as [Xorshift128State::to_string]. *)

val state_of_seed_pair : int64 -> int64 -> state
(** [seed0] gives [s0] (high half) and [s1], [seed1] gives [s2] and [s3]. *)

val state_to_seed_pair : state -> int64 * int64
val state_to_vector : state -> Gf2_matrix.vec
val state_of_vector : Gf2_matrix.vec -> state

type t
(** A generator ([Xorshift128]); [next] and [prev] change it in place. *)

val create : state -> t
val state : t -> state
val set_state : t -> state -> unit
val copy : t -> t

val next : t -> int
(** Steps once and returns the new [s3]. *)

val prev : t -> unit
(** Steps backwards: undoes exactly one {!next}. *)

val advance : t -> int -> unit
(** [advance t n] steps [n >= 0] times: one by one below 512 steps, else by the
    transition matrix to the [n]th power. *)

val rewind : t -> int -> unit
(** [rewind t n] undoes [n >= 0] steps, by the inverse matrix from 512 on. *)

val transition_matrix : Gf2_matrix.t
(** One {!next} as a matrix on {!state_to_vector}. *)

val inverse_transition_matrix : Gf2_matrix.t
(** One {!prev} as a matrix. *)

val transition_power : int -> Gf2_matrix.t
(** {!transition_matrix} to the [n]th power, from a table of the powers of two.
*)

val bdsp_gen_transform : int -> int
(** The game's output transform: [(raw mod 0xFFFFFFFF) + 0x80000000], wrapped to
    32 bits. *)

(** A window of pre-generated outputs ([Xorshift128List]): reads walk ahead of
    the window's head without stepping a generator per read. *)
module Window : sig
  type window

  val create : size_bits:int -> t -> window
  (** Fills [2^size_bits] outputs from a copy of the generator. The C++ takes
      the size as a template argument and rejects one that is not a power of two
      at compile time; taking its exponent keeps every size a power of two. *)

  val next_raw : window -> int
  val next_gen : window -> int
  val next_raw_modulo : window -> int -> int
  val next_gen_modulo : window -> int -> int

  val skip : window -> int -> unit
  (** Skips outputs without reading them ([advance]). *)

  val advance_state : window -> unit
  (** Drops the oldest output, generates one more and moves reads back to the
      new head. *)

  val reset_index : window -> unit
  (** Moves reads back to the head. *)
end
