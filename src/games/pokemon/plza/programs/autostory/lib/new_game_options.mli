(** 01.00a-new-game's choices as the program's options: the keys [language],
    [look] and [name] ({!Plza_story.New_game_choices.decls}, which
    plza.autostory's registry entry declares for [gamepilot run --options]),
    each replacing the matching arg of 01.00a-new-game's [new_game] event. The
    fork too reads the new game's choices from the program's options
    (PokemonLZA_AutoStoryNewGame.h). *)

type t = {
  language : Plza_story.New_game_choices.language option;
  look : int option;
  name : string option;
}
(** The options, each [None] when the run has none. *)

val none : t
(** No option: the plan's choices. *)

val given : t -> bool
(** Whether any option is given. *)

val over : t -> Plza_story.New_game_choices.t -> Plza_story.New_game_choices.t
(** The choices with each option in place of the plan's. *)

val of_run_options : Run_options.t -> (t, string) result
(** A run's checked options (each key's own values already checked by the
    registry), read. The rules across keys (the name's length in the language,
    its characters on the keyboard) are checked once, over the plan's args, by
    {!New_game_event.series_choices}. *)

val describe : Plza_story.New_game_choices.t -> string
(** For the log: [fr, look 5, "Kosmos"]. *)
