(** 128-bit vectors and 128x128 matrices over GF(2): the linear algebra behind
    jumping a {!Xorshift128} many steps at once.

    Port of the fork's [Pokemon/Pokemon_Gf2Matrix.{h,cpp}] (R21: same layout,
    same steps). Only the vector and matrix products are here; [gf2_solve_128]
    comes with the state solver that uses it.

    Words are [Int64.t] read as unsigned 64-bit: bits are moved with logical
    shifts only, so the sign bit is just bit 63. *)

type vec = { high : int64; low : int64 }
(** A 128-bit vector. Index 0 is the most significant bit of [high], index 127
    the least significant bit of [low] ([Gf2Vec128]). *)

val zero : vec
val get : vec -> int -> bool
val set : vec -> int -> bool -> vec
val xor : vec -> vec -> vec

val dot : vec -> vec -> bool
(** Parity of the bitwise AND: the GF(2) dot product. *)

type t
(** A 128x128 matrix, stored as 128 row vectors; vectors are columns
    ([Gf2Matrix128]). *)

val dimension : int
(** 128. *)

val init : (int -> vec) -> t
(** [init row] is the matrix whose row [r] is [row r], for [r] from 0 to
    {!dimension} - 1. Taking a function instead of an array means a matrix
    always has {!dimension} rows, as the C++ [std::array] does. *)

val row : t -> int -> vec
val identity : t
val equal : t -> t -> bool

val mul : t -> t -> t
(** The matrix product: row [i] is the XOR of the rows [k] of the right operand
    where row [i] of the left operand has bit [k] set. *)

val apply : t -> vec -> vec
(** Matrix times column vector. *)

val pow : t -> int -> t
(** [pow m n] is [m] to the [n]th power by squaring ([n >= 0]). *)
