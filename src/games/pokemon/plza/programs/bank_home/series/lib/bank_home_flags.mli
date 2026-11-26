(** What flags [plza.bank-home]'s series runner ({!Bank_home_runs}) takes:
    [gamepilot run]'s flags (Run_flags) with no game flags of its own, and the
    ones it refuses rather than ignores, as PLZA's story series refuses them. *)

type t = unit Run_flags.flags
(** The command's flags, with no game flags. *)

val parse : string list -> (t, string) result
(** The command's flags over the defaults; [Error] on an unknown flag or a bad
    value. *)

val takes : t -> (unit, string) result
(** Testing whole checkpoints only; [Error] names the flags given that it
    refuses (--mode other than testing, --preflight, --from-event, --to-event,
    --max-rounds). *)
