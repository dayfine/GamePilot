(** 128-bit vectors and 128x128 matrices over GF(2): the linear algebra behind
    jumping a {!Xorshift128} many steps at once.

    Port of the fork's [Pokemon/Pokemon_Gf2Matrix.{h,cpp}] (R21: same layout,
    same steps): vector and matrix products, and [gf2_solve_128] as {!solve}.

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

val of_rows : vec array -> t
(** Raises [Invalid_argument] unless there are {!dimension} rows. *)

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

val is_zero : vec -> bool

type solution = {
  consistent : bool;
      (** False when the system has no solution at all: normally corrupt
          observations rather than a bug in the caller. *)
  particular : vec;
      (** One solution, with every free variable zero. Zero unless [consistent].
      *)
  null_space_basis : vec array;
      (** Adding any XOR-combination of these to [particular] gives another
          solution. Empty means the solution is unique (or the system is
          inconsistent). *)
}
(** [Gf2SolveResult]; its [null_space_dimension] is the basis's length. *)

val solve : vec array -> bool array -> solution
(** [solve equations constants] solves [equations * x = constants] over GF(2) by
    Gauss-Jordan elimination, pivoting on the first row with the column set
    ([gf2_solve_128]). Any number of rows; more than 128 is normal. Raises
    [Invalid_argument] when the two arrays differ in length. *)
