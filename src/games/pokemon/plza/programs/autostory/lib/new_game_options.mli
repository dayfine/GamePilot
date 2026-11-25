(** 01.00a's choices given as the program's options (the keys [language], [look]
    and [name] of [gamepilot checkpoints --options]), each replacing the
    matching arg of 01.00a's [new_game] event; the plan's args stay the
    defaults. The fork too reads the new game's choices from the program's
    options (PokemonLZA_AutoStoryNewGame.h). *)

type t = {
  language : Plza_story.New_game_choices.language option;
  look : int option;
  name : string option;
}

val none : t
(** No option given: the plan's choices. *)

val given : t -> bool
(** Whether any option is given. *)

val over : t -> Plza_story.New_game_choices.t -> Plza_story.New_game_choices.t
(** The choices with each option given in place of the plan's. *)

val language : t -> string -> (t, string) result
(** The [language] option: a tag of {!Plza_story.New_game_choices.tags}; [Error]
    on one it does not know, listing those 01.00a types a name in. *)

val look : t -> string -> (t, string) result
(** The [look] option: a whole number from 1 to 8; [Error] otherwise. *)

val name : t -> string -> (t, string) result
(** The [name] option, any text: {!check} refuses one 01.00a cannot type. *)

val check : t -> (unit, string) result
(** The options against {!Plza_story.New_game_choices.problem}, over the fork's
    defaults (English when no [language]), whatever their order; [Error] is the
    refusal 01.00a would make. The plan's language is checked too when the
    series loads it. *)

val describe : Plza_story.New_game_choices.t -> string
(** For the log: [fr, look 5, "Kosmos"]. *)
