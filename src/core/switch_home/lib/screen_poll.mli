(** Reading a Switch game's screen until a check holds, giving up after a
    timeout, and stopping at once on the HOME menu: the game is not running
    there, and no wait in it can pass. Ported from the fork's
    [Pokemon/AutoStory/Engine/Pokemon_ScreenWait.h] ([plza/mvp-0101]) as its
    callers use it: one read that holds is enough, and the HOME menu fails the
    wait. Any game's screen read works: the caller says when it was read and
    whether it is the HOME menu. *)

type 'screen game_steps = {
  read_screen : unit -> 'screen;
      (** Read the screen once the inputs are done. *)
  wait : int -> unit;  (** Wait that many ms. *)
}
(** What the poll reads and does in the game. *)

(** How a poll ended. *)
type 'screen outcome =
  | Holds of 'screen  (** The read on which the check held. *)
  | Timed_out of 'screen  (** The last read, once the time was up. *)
  | Home_menu  (** The HOME menu showed: the game is not running. *)

val until :
  'screen game_steps ->
  at_ms:('screen -> float) ->
  home_menu:('screen -> bool) ->
  poll_ms:int ->
  timeout_ms:int ->
  ('screen -> bool) ->
  'screen outcome
(** [until steps ~at_ms ~home_menu ~poll_ms ~timeout_ms holds] reads the screen,
    then waits [poll_ms] between reads until [holds] does. The HOME menu is
    checked before [holds]. It times out once [timeout_ms] has passed since the
    first read on the reads' clock ([at_ms]), or after
    [timeout_ms / poll_ms + 1] reads, whichever comes first, so a clock that
    stands still still ends it. *)

val not_running : string
(** ["the game is not running: the Switch HOME menu is showing"]: the detail of
    a {!Home_menu} failure. *)
