(** The order a program's checkpoints run in, from their ids: name order, except
    that a checkpoint split in two runs its lettered part first. The fork splits
    mg-05 so its double battle retries from a save just outside the trainer's
    sight: mg-05a (buy, cut, arrange the party) ends where mg-05 starts, so the
    chain is mg-04, mg-05a, mg-05, mg-06, where name order puts mg-05 before
    mg-05a. *)

val compare : string -> string -> int
(** An id with lowercase letters after its last digit (["mg-05a"]) sorts before
    the id without them (["mg-05"]), after those of lower numbers. *)
