(** 00-new-game's new-game choices in a PLZA series, checked before the console
    moves: the program's options over its plan's args
    ({!Plza_autostory.New_game_event.series_choices}), printed. *)

val check :
  options:Plza_autostory.New_game_options.t ->
  Plza_engine.Plan.t list ->
  (unit, string) result
(** [Error] on new-game choices 00-new-game would refuse, or on [options] given
    to a series with no 00-new-game; the choices printed otherwise. *)
