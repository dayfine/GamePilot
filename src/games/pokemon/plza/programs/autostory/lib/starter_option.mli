(** plza.autostory's [starter] option ({!Plza_story.Starter.decls}): read from
    the run's options, and checked against the series before the console moves.
    The fork's Starter option (PokemonLZA_AutoStory.cpp) is a setting of every
    run; here, as for 00.00-new-game's choices ({!New_game_event}), an option
    that would do nothing is refused: only 01.04's walk to the starter reads it,
    and once a save has its starter, nothing later in the story needs to know it
    (the story battles press the most effective move the screen shows,
    {!Plza_story.Battle}). *)

val of_run_options :
  Run_options.t -> (Plza_story.Starter.t option, string) result
(** The run's checked options' [starter]; [None] when not given. *)

val series_check :
  Plza_story.Starter.t option ->
  Plza_engine.Plan.checkpoint list ->
  (unit, string) result
(** [Error] when a starter is given and no checkpoint of the series has a walk
    with [to_starter] (the series starts after 01.04-starter-and-andi). *)
