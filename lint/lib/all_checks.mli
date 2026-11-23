(** Every check over the configured tree. *)

val run : Config.t -> (Finding.t list, string) result
(** Findings after the exceptions file is applied, sorted by path and line.
    [Error] for a missing root or an unreadable exceptions file. *)
