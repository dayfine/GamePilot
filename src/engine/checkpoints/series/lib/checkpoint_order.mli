(** The order a program's checkpoints run in, from their ids: name order, except
    that a checkpoint split in two runs its lettered part first. The first part
    of a split checkpoint, [cp-05a], ends where [cp-05] starts, so the chain is
    cp-04, cp-05a, cp-05, cp-06, where name order puts cp-05 before cp-05a (the
    fork splits a checkpoint so a step that may fail retries from a save just
    before it). Ids that lead with their place in the chain (01-..., 02-...)
    keep name order. *)

val compare : string -> string -> int
(** An id with lowercase letters after its last digit (["cp-05a"]) sorts before
    the id without them (["cp-05"]), after those of lower numbers. *)
