(** What flags PLZA's series runner ({!Runs}) takes: [gamepilot run]' flags
    (Run_flags), no game flag of its own, the keys its [--options] take
    (01.00a's new-game choices, {!Plza_autostory.New_game_options}), and the
    flags it refuses rather than ignores. *)

type t = Plza_autostory.New_game_options.t Run_flags.flags
(** The flags with the options read into [game]. *)

val option_keys : Plza_autostory.New_game_options.t Run_flags.option_keys
(** The keys [plza.autostory] takes in [--options]: [language] (a tag), [look]
    (1 to 8) and [name]; docs/guide/plza.autostory.md lists them for the player.
*)

val parse : string list -> (t, string) result
(** The command's flags over the defaults, [--options] read by {!option_keys};
    [Error] on an unknown flag, a bad value, an option key autostory does not
    take, or new-game choices 01.00a would refuse
    ({!Plza_autostory.New_game_options.check}). *)

val usage : string
(** PLZA's lines in [gamepilot run]'s usage. *)

val takes : t -> (unit, string) result
(** The flags this runner takes: testing whole checkpoints; [Error] names the
    ones given that it refuses (--mode other than testing, --preflight,
    --from-event, --to-event, --max-rounds). *)
