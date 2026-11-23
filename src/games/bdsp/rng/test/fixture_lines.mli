(** Golden vector records written by [golden/generate_golden.cpp]. *)

type record = { op : string; inputs : string list; expected : string }

val read : string -> record list
val hex : string -> int
val hex32 : int -> string
val float17 : float -> string

val check_op : record list -> string -> (string list -> string) -> unit
(** [check_op records op compute] reports one case for all records of [op]: each
    record's [compute inputs] must equal its expected text. *)
