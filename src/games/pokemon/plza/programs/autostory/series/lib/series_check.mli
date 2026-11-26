(** A PLZA series' plans, loaded and checked before the console moves: each
    plan's own keys ({!Plza_autostory.Plan_check}), and 00.00-new-game's
    choices, the program's options over its plan's args
    ({!Plza_autostory.New_game_event.series_choices}), printed; and the
    [starter] option, refused for a series that does not walk to the starter
    ({!Plza_autostory.Starter_option.series_check}), printed. *)

val check :
  options:Plza_autostory.New_game_options.t ->
  Plza_engine.Plan.t list ->
  (unit, string) result
(** [Error] on new-game choices 00.00-new-game would refuse, or on [options]
    given to a series with no 00.00-new-game; the choices printed otherwise. *)

val check_all :
  options:Plza_autostory.New_game_options.t ->
  starter:Plza_story.Starter.t option ->
  Plza_engine.Plan.t list ->
  (unit, string) result
(** Each plan's keys checked in order, then {!check}, then the [starter]; the
    first [Error] otherwise. *)
