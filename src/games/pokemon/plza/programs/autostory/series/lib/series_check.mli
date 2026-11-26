(** A PLZA series' plans, loaded and checked before the console moves: each
    plan's own keys ({!Plza_autostory.Plan_check}), and 01.00a-new-game's
    choices, the program's options over its plan's args
    ({!Plza_autostory.New_game_event.series_choices}), printed. *)

val check :
  options:Plza_autostory.New_game_options.t ->
  Plza_engine.Plan.t list ->
  (unit, string) result
(** [Error] on new-game choices 01.00a-new-game would refuse, or on [options]
    given to a series with no 01.00a-new-game; the choices printed otherwise. *)

val load_checked :
  (string -> (Plza_engine.Plan.t, string) result) ->
  options:Plza_autostory.New_game_options.t ->
  string list ->
  (Plza_engine.Plan.t list, string) result
(** Each checkpoint's plan, loaded in order, its keys checked, then {!check};
    the first [Error] otherwise. *)
