(** How PLZA prints its rules ({!Plza_terms}) in a log line, a failure or a
    plan's text. *)

include Engine_text.Terms_text.TEXT with module T = Plza_terms

val walk : Plza_terms.Walk_args.t -> string
(** ["walk [0, 4500] [90, 10000] until fade_white"]: the legs as the plan writes
    them, then [held], the wait first, the end and its [end_after_ms] when set.
*)
