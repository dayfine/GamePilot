(** Waits until the player has free control before a walk starts: ported from
    [check_can_walk] and [check_free_control] ([PokemonLZA_AutoStoryWalks.cpp],
    fork #754), over the C++'s [Pokemon::wait_for] with its default rule
    ([Pokemon_ScreenWait.h]: one look confirms, the HOME menu fails) and its
    [ConfirmStreak] and [HoldTimer] ([Pokemon_ScreenTimers.h]).

    A look every 250 ms for up to 30 s. Control is free on two looks in a row of
    the party bar or the controls hint with nothing over them, or after 10 s
    with nothing busy (no text, box or fade) and no sign of control: longer than
    the ~7 s from the end of 01.01's scenes to control. *)

type game_steps = {
  look : unit -> Walk_look.t;
      (** Look at the screen once the inputs are done. *)
  wait : int -> unit;  (** Wait that many ms. *)
  log : string -> unit;
}
(** What the wait reads and does in the game. *)

val check_can_walk :
  game_steps -> string -> (unit, Engine_run.Failure.cause) result
(** [check_can_walk steps walk]: [Ok] once control is free; [walk_not_free]
    after 30 s without it (naming what was last busy), or [game_not_running]
    (which repeats) on the HOME menu. [walk] names the walk in the log. *)
