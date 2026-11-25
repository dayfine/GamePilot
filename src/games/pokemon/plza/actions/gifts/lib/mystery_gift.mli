(** Claiming Mystery Gifts: stages 1 and 2 of [plza_claim_and_bank.sh] from the
    BDSPLab lab tools (console B, 2026-11-20), its presses and waits. The
    screens are read by {!Plza_readers.Mystery_gift_screen} and the code
    keyboard by {!Switch_home.Code_keyboard}; their probes must be subscribed
    ({!probes}).

    - {!open_gifts}: from the main menu (open), row 5 (Link Play), A (2 s);
      Right, Right, Down (each 80 ms, released 300) to Mystery Gift; A (2 s).
    - {!open_internet_list}: A (1.5 s), A (4 s) to connect, then A (2 s) until
      the gift list is active, 25 at most ([wait_mg_list]).
    - {!choose_gift}: Down three times to the 4th gift (Vivillon, Poké Ball
      Pattern), A (8 s).
    - {!leave_card}: the card, read for 1 s within 30 s, then A (3 s)
      ([wait_mg_card_and_dismiss], which read every 2 s); B (1.5 s) and A (2 s):
      "stop for now?", yes.
    - {!open_keyboard}: Down, A (2 s); A (2 s) until the keyboard opens, 25 at
      most ([wait_mg_keyboard]).
    - {!claim_code}: the code typed; + (5 s); the list again; A (8 s) on the
      code's gift. {!dismiss_card} then dismisses its card.
    - {!disconnect}: B (1.5 s), A (4.5 s): "you will be disconnected", yes; A
      (2.5 s); B (2 s): back on the main menu.

    Where it differs: the list and the keyboard count once they have read so for
    1 s (a white fade reads as the list for a moment). When no card shows in 30
    s the script pressed A anyway; here it is an error (the gift may have been
    received; nothing is saved yet). The gift is found by its name
    ({!Plza_readers.Mystery_gift_screen.gift_item}), not taken as the 4th, and
    the cursor is read on it before A; the list is read without a press there,
    as A would claim the selected gift. Each step is its own call, so a run can
    start or stop on the screen between two ({!Claim_gifts}). *)

val probes :
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  gift_name:string option ->
  Wire.probe_spec list
(** The menu's, the gift screens', the keyboard's, the Boxes' and the SAVE
    dialog's probes; [gift_name] the reference of the Internet gift's name
    template in the game's language, [None] when the run does not claim it
    ({!Claim_gifts.gift_name_template}). *)

val open_gifts : log:(string -> unit) -> (unit, string) result
val open_internet_list : log:(string -> unit) -> (unit, string) result
val choose_gift : log:(string -> unit) -> (unit, string) result
val leave_card : log:(string -> unit) -> (unit, string) result
val open_keyboard : log:(string -> unit) -> (unit, string) result
val dismiss_card : log:(string -> unit) -> (unit, string) result

val await_list : unit -> (unit, string) result
(** The gift list read for 1 s within 3 s, no press. *)

val await_card : unit -> (unit, string) result
(** A gift's card read for 1 s within 30 s, no press: the white fade and the
    receive animation before it are not the card. *)

val await_keyboard : unit -> (unit, string) result
(** The code keyboard read for 1 s within 5 s, no press. *)

val claim_code :
  log:(string -> unit) -> picture:Wire.box -> string -> (unit, string) result

val disconnect : unit -> unit
