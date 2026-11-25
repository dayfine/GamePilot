(** What flags PLZA's series runner ({!Runs}) takes: [gamepilot run]' flags
    (Run_flags) with no game flags of its own, and the ones it refuses rather
    than ignores. *)

type t = unit Run_flags.flags
(** The command's flags, with no game flags. *)

val parse : string list -> (t, string) result
(** The command's flags over the defaults; [Error] on an unknown flag or a bad
    value. *)

val takes : t -> (unit, string) result
(** The flags this runner takes: testing whole checkpoints; [Error] names the
    ones given that it refuses (--mode other than testing, --preflight,
    --from-event, --to-event, --max-rounds). *)
