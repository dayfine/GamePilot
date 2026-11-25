(** The commands of [gamepilot ctl], one per line of a script or one from the
    command line, in the lab's labB.sh format: [press A 100 800] (button, hold
    ms, wait ms after the release), [dpad DOWN 160 800], [shot NAME], [wait MS];
    [#] starts a comment. Buttons are the daemon's (protocol/v1), any case: the
    GBA buttons, PLUS and MINUS naming Start and Select as the Switch's GBA app
    maps them, and the Switch's own HOME, X, Y, ZL and ZR, which only the Switch
    backend takes. *)

type step =
  | Press of { button : Wire.button; hold_ms : int; wait_ms : int; times : int }
      (** [times] presses, each held [hold_ms], then [wait_ms] released *)
  | Wait of int  (** ms *)
  | Shot of string  (** a PNG path ([.png] added when it has no extension) *)
  | Read of string  (** a reader's name *)
  | Status

val default_hold_ms : int
(** 100 *)

val default_wait_ms : int
(** 500 *)

val parse_words : string list -> (step, string) result
(** One command as words:
    - [press BUTTON [HOLD [WAIT]]]
    - [dpad DIRECTION [N]]: [N] taps (default 1); [dpad DIRECTION HOLD WAIT]:
      one tap
    - either also with [--hold MS] and [--wait MS]
    - [wait MS], [shot FILE], [read READER], [status]. *)

val parse_line : string -> (step option, string) result
(** One script line: [None] for a blank or comment line. *)

val sends_input : step -> bool
(** Presses and waits need the input lease; shots, reads and status do not. *)

val commands : step -> Wire.command list
(** The batch a press or a wait submits; [[]] for the others. *)
