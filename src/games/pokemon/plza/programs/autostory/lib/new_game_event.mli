(** 01.00a-new-game's [new_game] event: the choices it plays, its plan's args
    ([language], a tag of {!Plza_story.New_game_choices.tags}; [look]; [name];
    each the fork's default when absent) with the program's options over them
    ({!New_game_options}), and a series' new games checked before the console
    moves. *)

val choices :
  options:New_game_options.t ->
  Plza_engine.Plan.event ->
  Json_field.obj ->
  (Plza_story.New_game_choices.t, Engine_run.Failure.cause) result
(** The event's args, then the options over them; [Error] [bad_args] (repeats)
    on an arg it does not know or a language tag that is not one. *)

val series_choices :
  options:New_game_options.t ->
  Plza_engine.Plan.checkpoint list ->
  (Plza_story.New_game_choices.t list, string) result
(** The choices each [new_game] event of the checkpoints plays, in order;
    [Error] on a bad arg, on choices 01.00a-new-game refuses
    ({!Plza_story.New_game_choices.problem}), or on options given to a series
    with no [new_game] event: an option that would do nothing is refused, not
    ignored. *)
