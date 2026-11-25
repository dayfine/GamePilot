(** A PLZA series' plans checked before the console moves: each plan's own keys
    ({!Plza_autostory.Plan_check}) and 01.00a's new-game choices, the program's
    options over its plan's args
    ({!Plza_autostory.New_game_event.series_choices}), printed. *)

val all_ok : ('a, string) result list -> ('a list, string) result
(** Every value, in order; the first [Error] otherwise. *)

val check :
  options:Plza_autostory.New_game_options.t ->
  Plza_engine.Plan.t list ->
  (unit, string) result
(** [Error] on the first plan whose keys are bad, on new-game choices 01.00a
    would refuse, or on [options] given to a series with no 01.00a; the choices
    printed otherwise. *)
