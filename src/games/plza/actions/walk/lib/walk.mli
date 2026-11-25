(** A PLZA walk: timed legs of the left stick ({!Plza_terms.Walk_args}), played
    only once the player has free control, and, with an end, the last leg held
    in slices until it shows. A transparent port of [run_story_move],
    [finish_walk], [walk_until] and the action table's [walk_step]
    ([PokemonLZA_AutoStoryWalks.cpp], [PokemonLZA_AutoStoryActionTable.cpp],
    fork #754, [plza/mvp-0101]): the same presses, order and timings.

    The camera follows the player and a walk goes where it looks, so a turn is
    an L press (the camera recentres behind the player, 100 ms held, 150 ms
    released), a 150 ms tilt toward the turn (released 100 ms), and L again; a
    walk then holds the stick straight on. A {!Plza_terms.Walk_args.Held} move
    holds each leg at its own angle instead, with an L press before a turned leg
    after the first. A turn or walk after which the screen stayed still was
    dropped (or walked into a wall) and is played once more. Every walk and hold
    asks to run ({!Stick_input.Run}); [walk_only] walks it, as before dash is
    unlocked (01.01). *)

type game_steps = {
  submit : Wire.command -> unit;
      (** Send one input and return once it is done. *)
  look : unit -> Walk_look.t;  (** Look at the screen. *)
  log : string -> unit;  (** A line for the log and the watch page. *)
  log_detail : string -> unit;  (** A line for the log alone. *)
}
(** What a walk reads and does in the game. *)

type outcome = (unit, Engine_run.Failure.cause) result
(** [Ok], or the walk's failure. *)

val run_story_move :
  game_steps -> walk_only:bool -> Plza_terms.Walk_args.move -> outcome
(** Plays every leg as timed. Fails only on a stick that cannot be sent. *)

val finish_walk : game_steps -> string -> unit
(** One look once the legs are done, logged, so queued inputs have finished
    before the step ends. *)

val walk_until :
  game_steps ->
  walk_only:bool ->
  string ->
  Plza_terms.Walk_args.move ->
  until:Plza_terms.Walk_args.until ->
  end_after_ms:int ->
  outcome
(** [walk_until steps ~walk_only walk move ~until ~end_after_ms]: plays all but
    the last leg's walk, then holds the last leg in slices of up to 250 ms,
    looking after each, until [until] shows (an end event seen before
    [end_after_ms] of the leg was passed on the way) or a black fade ends it (a
    scene takes over). The leg's time is the budget: [walk_no_end] after it with
    no end event, [walk_no_scene] when control stayed free. With
    {!Plza_terms.Walk_args.Scene}, two busy looks in a row (text, a box or a
    fade) end it. *)

val walk_step :
  game_steps -> walk_only:bool -> string -> Plza_terms.Walk_args.t -> outcome
(** A walk event: the wait first, then {!Free_control.check_can_walk}, then
    {!walk_until} with an end, or the legs and {!finish_walk} without one. *)
