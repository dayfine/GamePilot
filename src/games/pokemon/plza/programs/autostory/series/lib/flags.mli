(** What flags PLZA's series runner ({!Runs}) takes: [gamepilot checkpoints]'
    flags (Checkpoints_flags) with PLZA's own, 01.00a's new-game choices
    ({!Plza_autostory.New_game_options}: [--language], [--look], [--name]), and
    the ones it refuses rather than ignores. *)

type t = Plza_autostory.New_game_options.t Checkpoints_flags.flags

val parse : string list -> (t, string) result
(** The command's flags over the defaults; [Error] on an unknown flag or a bad
    value, among them new-game choices 01.00a would refuse
    ({!Plza_autostory.New_game_options.check}). *)

val usage : string
(** PLZA's lines in [gamepilot checkpoints]' usage, its new-game options among
    them. *)

val takes : t -> (unit, string) result
(** The flags this runner takes: testing whole checkpoints; [Error] names the
    ones given that it refuses (--mode other than testing, --preflight,
    --from-event, --to-event, --max-rounds). *)
