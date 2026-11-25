(** What ends a walk's last leg, judged on each look after a slice: ported from
    [end_event_look] and [walk_until]'s scene watch and failures
    ([PokemonLZA_AutoStoryWalks.cpp], fork #754). *)

val end_event_look :
  log:(string -> unit) ->
  log_detail:(string -> unit) ->
  string ->
  Plza_terms.Walk_args.end_event ->
  end_after_ms:int ->
  Walk_look.t ->
  int ->
  (unit, Engine_run.Failure.cause) result option
(** [end_event_look ~log ~log_detail walk event ~end_after_ms look held]: [None]
    walks on; [Some (Ok ())] ends the walk, on [event] once the leg has been
    held [end_after_ms] (before that it was passed on the way), or on a black
    fade (a scene takes over). *)

val scene_look :
  (string -> unit) ->
  string ->
  Walk_look.t ->
  int ->
  (unit, Engine_run.Failure.cause) result option
(** [scene_look log walk]: a watch over the looks that ends the walk
    ([Some (Ok ())]) on the second busy look in a row (text, a box or a fade).
    Each call makes a fresh watch. *)

val no_end :
  string -> Plza_terms.Walk_args.until -> int -> Engine_run.Failure.cause
(** [no_end walk until elapsed]: the failure once the last leg's budget is
    spent: [walk_no_scene] for {!Plza_terms.Walk_args.Scene}, [walk_no_end] for
    an event. *)
