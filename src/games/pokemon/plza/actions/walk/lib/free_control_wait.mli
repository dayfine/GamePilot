(** Waits until the player has free control before a walk starts. Ported from
    [PokemonLZA_AutoStoryWalks.cpp] (fork #754, [plza/mvp-0101]), over the
    screen poll {!Switch_home.Screen_poll} and the two timers of
    [Pokemon/AutoStory/Engine/Pokemon_ScreenTimers.h].

    A screen read every 250 ms. Control is free on two reads in a row of the
    party bar or the controls hint with nothing over them: about 0.5 s when
    control is already free, as it is for most walks. An A prompt with nothing
    busy held 1 s is control too (the fork's [PROMPT_IS_CONTROL], [plza/lean]:
    at 01.03 no party bar shows). Two longer limits, kept as the C++ has them:
    after 10 s with nothing busy (no text, box or fade) and no sign of control
    either, control is taken as free (longer than the ~7 s from the end of
    01.01's scenes to control, where no sign shows); and 30 s without free
    control is the timeout, which only a stuck game reaches. *)

type game_steps = {
  read_screen : unit -> Walk_screen.t;
      (** Read the screen once the inputs are done. *)
  wait : int -> unit;  (** Wait that many ms. *)
  log : string -> unit;
}
(** What the wait reads and does in the game. *)

val screen_game_steps :
  submit:(Wire.command -> unit) ->
  read_screen:(unit -> Walk_screen.t) ->
  log:(string -> unit) ->
  game_steps
(** The steps of a walk, its waits sent as inputs. *)

val wait : game_steps -> string -> (unit, Engine_run.Failure.cause) result
(** [wait steps walk]: [Ok] once control is free; [walk_not_free] after 30 s
    without it (naming what was last busy), or [game_not_running] (which
    repeats) on the HOME menu. [walk] names the walk in the log. *)
