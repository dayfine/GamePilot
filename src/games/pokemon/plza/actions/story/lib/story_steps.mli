(** What PLZA's story actions read and do in the game, and the screen waits they
    share: the fork's [PlzaBackend] (press, observe, wait, log) and
    [Pokemon::wait_for] / [poll_until] of Pokemon/AutoStory/Engine/
    Pokemon_ScreenWait.h ([plza/lean]), as the PLZA actions call them. *)

type game_steps = {
  submit : Wire.command -> unit;
      (** Send one input and return once it is done. *)
  read_screen : unit -> Story_look.t;
      (** Read the screen once the inputs are done. *)
  log : string -> unit;  (** A line for the log and the watch page. *)
  log_detail : string -> unit;  (** A line for the log alone. *)
}
(** What a story action reads and does in the game. *)

type outcome = (unit, Engine_run.Failure.cause) result
(** [Ok], or the action's failure. *)

val press_hold_ms : int
(** 160: how long the story actions hold a button. *)

val press_release_ms : int
(** 240: the release after most presses. *)

val seconds : float -> float
(** Milliseconds as seconds, for a log line. *)

val press : game_steps -> Wire.button -> hold_ms:int -> release_ms:int -> unit
(** The button held [hold_ms], then [release_ms] with nothing held. *)

val wait : game_steps -> int -> unit
(** Nothing held for that many ms. *)

val walk_game_steps : game_steps -> Plza_walk.Walk.game_steps
(** The steps as the walk takes them. *)

val game_not_running : Engine_run.Failure.cause
(** The HOME menu showed: [game_not_running], which repeats. *)

(** How a screen wait ended. *)
type waited =
  | Matched of { look : Story_look.t; looks : int; elapsed_ms : float }
      (** The check held on [looks] reads in a row (and for the hold asked). *)
  | Timed_out
  | Home_menu

type rule = {
  poll_ms : int;
  timeout_ms : int;
  confirm_looks : int;  (** Reads in a row the check must hold on; 1 for one. *)
  confirm_hold_ms : int;  (** How long it must hold; 0 for none. *)
}
(** The fork's [WaitRule]. *)

val rule :
  ?confirm_looks:int ->
  ?confirm_hold_ms:int ->
  poll_ms:int ->
  timeout_ms:int ->
  unit ->
  rule

val poll_until :
  game_steps ->
  rule ->
  (Story_look.t -> bool) ->
  (Story_look.t -> unit) ->
  waited
(** [poll_until steps rule holds act]: reads the screen until [holds] has held
    as the rule asks, calling [act] on every other read (which presses or
    waits). Ends at once on the HOME menu; times out once [timeout_ms] has
    passed since the first read, or after [timeout_ms / poll_ms + 1] reads. *)

val wait_for : game_steps -> rule -> (Story_look.t -> bool) -> waited
(** {!poll_until} that waits [poll_ms] between reads. *)
