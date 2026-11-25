(** A walk's timed legs played on the left stick, as
    [PokemonLZA_AutoStoryWalks.cpp] plays them: the presses, order and timings
    {!Walk} describes. *)

type game_steps = {
  submit : Wire.command -> unit;
      (** Send one input and return once it is done. *)
  read_screen : unit -> Screen.t;  (** Read the screen. *)
  log : string -> unit;  (** A line for the log and the watch page. *)
  log_detail : string -> unit;  (** A line for the log alone. *)
}
(** What a walk reads and does in the game. *)

val play_legs :
  game_steps ->
  walk_only:bool ->
  Plza_rules.Walk_args.move ->
  (unit, Engine_run.Failure.cause) result
(** Every leg as timed; fails only on a tilt that cannot be sent. *)

val play_legs_but_last_walk :
  game_steps ->
  walk_only:bool ->
  Plza_rules.Walk_args.move ->
  (unit, Engine_run.Failure.cause) result
(** Every leg but the last one's walk (its facing, or its L when steered). *)

val hold_last_leg :
  game_steps ->
  walk_only:bool ->
  Plza_rules.Walk_args.move ->
  int ->
  (unit, Engine_run.Failure.cause) result
(** One slice of that many ms of the last leg, run at its angle when steered,
    else straight on. *)

val last : 'a list -> 'a
(** The last of a non-empty list. *)
