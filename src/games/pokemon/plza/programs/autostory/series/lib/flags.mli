(** What flags PLZA's series runner ({!Runs}) takes: [gamepilot checkpoints]'
    flags (Checkpoints_flags) with no game flags of its own, and the ones it
    refuses rather than ignores. *)

type t = unit Checkpoints_flags.flags

val parse : string list -> (t, string) result
(** The command's flags over the defaults; [Error] on an unknown flag or a bad
    value. *)

val takes : t -> (unit, string) result
(** The flags this runner takes: testing whole checkpoints; [Error] names the
    ones given that it refuses (--mode other than testing, --preflight,
    --from-event, --to-event, --max-rounds). *)
