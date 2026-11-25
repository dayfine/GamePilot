(** How PLZA prints its rules ({!Plza_rules}) in a log line, a failure or a
    plan's text. *)

include Engine_text.Rules_text.TEXT with module T = Plza_rules

val walk : Plza_rules.Walk_args.t -> string
(** ["walk [0, 4500] [90, 10000] until fade_white"]: the legs as the plan writes
    them, then [steer], the wait before, the end and its [earliest_end_ms] when
    set. *)
