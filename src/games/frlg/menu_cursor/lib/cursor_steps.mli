(** A menu's cursor moved by reading where it is, never by counting presses.
    FireRed keeps a menu's row from the last time it was open (the Start menu,
    the party; a save state keeps them too), and drops a tap while a menu is
    still sliding or fading in. So each step reads the row, taps once toward the
    target, and waits for the read row to change; a tap that changed nothing is
    tapped again. Shared by the overworld's menu actions and the battle's party
    list. *)

type outcome =
  | Reached
  | Unread  (** no row read within the timeout: the menu did not show *)
  | Stuck of int  (** {!max_taps} taps and still on this row *)

val read_timeout_ms : int
(** How long the menu may take to read a row before each step: 3 s. *)

val tap_timeout_ms : int
(** How long a tap may take to move the read row before it counts as lost and is
    tapped again: 400 ms. *)

val max_taps : int
(** Taps toward one row before giving up: 16. *)

val step_to :
  ?timeout_ms:int ->
  tap:(Wire.button -> unit) ->
  (Effects.measurements -> int option) ->
  int ->
  outcome
(** Taps DOWN (to a higher row) or UP with [tap] until the reader gives this
    row. [timeout_ms] (default {!read_timeout_ms}) bounds each read. *)
