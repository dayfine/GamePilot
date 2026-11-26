(** What flags PLZA's series runner ({!Runs}) takes: [gamepilot run]'s flags
    (Run_flags), its own [--options KEY=VALUE] (00-new-game's new-game choices,
    {!Plza_autostory.New_game_options}), and the flags it refuses rather than
    ignores.

    [--options] is repeatable, one pair each
    ([--options language=fr --options look=5]); a value keeps every [=] and
    comma after the first [=]. Its keys: [language] (a tag), [look] (1 to 8) and
    [name]. *)

type t = Plza_autostory.New_game_options.t Run_flags.flags
(** The command's flags, the options read into [game]. *)

val usage : string
(** The [--options] line of [gamepilot run]'s usage. *)

val parse : string list -> (t, string) result
(** The command's flags over the defaults, then the [--options] pairs read in
    the order given; [Error] on an unknown flag, a bad value, a pair with no
    [=VALUE] or an empty key, a key given twice, a key autostory does not take
    (naming those it takes), or new-game choices 00-new-game would refuse
    ({!Plza_autostory.New_game_options.check}). *)

val takes : t -> (unit, string) result
(** The flags this runner takes: testing whole checkpoints; [Error] names the
    ones given that it refuses (--mode other than testing, --preflight,
    --from-event, --to-event, --max-rounds). *)
