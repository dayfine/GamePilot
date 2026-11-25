(** How much money a checkpoint promises: a range, or what it spent from the
    money it started with, so the promise holds on any save. *)

type t =
  | Range of { min : int; max : int }
      (** Money from [min] to [max], both included. *)
  | Spent of int
      (** Exactly this much less than at the checkpoint's start (negative: more
          than at the start): what the checkpoint's purchases cost, whatever
          money the save started with. *)

val text : t -> string
(** ["money 100 to 200"], ["money spent 4100"]. *)
