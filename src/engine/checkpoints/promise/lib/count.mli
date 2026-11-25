(** How many of a thing (a bag item, Game Corner coins) a checkpoint promises. A
    count copied from one save holds on that save only: a checkpoint that buys
    or uses something promises what it changed ({!Gained}), and one whose later
    checkpoints need a stock promises a floor ({!At_least}). *)

type t =
  | Exactly of int  (** Exactly this many. *)
  | Gained of int
      (** Exactly this many more than at the checkpoint's start (negative: this
          many used), whatever the save started with. *)
  | At_least of int  (** At least this many. *)

val text : t -> string
(** ["x2"], ["gained 2"], ["used 1"], ["at least 100"]. *)
