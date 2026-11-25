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
(** The vector with every bit clear. *)

val get : vec -> int -> bool
(** [get v i] is bit [i] (0 to 127, see {!vec}). *)

val set : vec -> int -> bool -> vec
(** [set v i b] is [v] with bit [i] set to [b]. *)

val xor : vec -> vec -> vec
(** Bitwise exclusive or: vector addition over GF(2). *)

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
(** [row m r] is row [r] of [m] (0 to 127). *)

val identity : t
(** The identity matrix: bit [r] set in row [r]. *)

val equal : t -> t -> bool
(** Whether every row is the same. *)

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

val solve : (vec * bool) array -> solution
(** [solve equations] solves the system whose equations are each a coefficient
    row and its constant ([row . x = constant]) over GF(2) by Gauss-Jordan
    elimination, pivoting on the first row with the column set
    ([gf2_solve_128]). Any number of rows; more than 128 is normal. The C++
    takes the rows and constants as two vectors and throws when their lengths
    differ; pairing them makes that impossible. *)
