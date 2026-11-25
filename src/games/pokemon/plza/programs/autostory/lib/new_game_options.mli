(** 01.00a's choices given as the program's options ([--language], [--look],
    [--name] of [gamepilot checkpoints]), each replacing the matching arg of
    01.00a's [new_game] event; the plan's args stay the defaults. The fork too
    reads the new game's choices from the program's options
    (PokemonLZA_AutoStoryNewGame.h). *)

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

val valued : t -> string -> string -> (t, string) result option
(** [valued t flag value]: [--language] (a tag of
    {!Plza_story.New_game_choices.tags}; the error lists those 01.00a types a
    name in), [--look] (1 to 8) or [--name] with its value; [Some (Error _)] on
    a tag it does not know or a look that is not a whole number from 1 to 8;
    [None] for any other flag (Checkpoints_flags' game hook). *)

val check : t -> (unit, string) result
(** The options against {!Plza_story.New_game_choices.problem}, over the fork's
    defaults (English when no [--language]); [Error] is the refusal 01.00a would
    make. The plan's language is checked too when the series loads it. *)

val describe : Plza_story.New_game_choices.t -> string
(** For the log: [fr, look 5, "Kosmos"]. *)

val usage : string
(** The options' lines in [gamepilot checkpoints]' usage. *)
