(** A press as the lab's scripts write it ([press X 100 1500],
    [dpad DOWN 80 300]): the button held [hold_ms], then [cooldown_ms] with
    nothing held before the next, as {!Switch_presses.press} does it. *)

type t = { button : Wire.button; hold_ms : int; cooldown_ms : int }
(** One press: the button, how long it is held, and the wait after it. *)

val command : t -> Wire.command
(** The daemon's press. *)

val press : t -> unit
(** Presses it and returns when the daemon has done the hold and the cooldown.
*)

val press_all : t list -> unit
(** Presses them in order, as one batch. *)

val times : int -> t -> t list
(** The press [n] times. *)
