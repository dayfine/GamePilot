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
    - {!leave_card}: the card, read every 2 s for 30 s, then A (3 s)
      ([wait_mg_card_and_dismiss]); B (1.5 s) and A (2 s): "stop for now?", yes.
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
  gift_name:string ->
  Wire.probe_spec list
(** The menu's, the gift screens' and the keyboard's probes; [gift_name] the
    reference of the Internet gift's name template. *)

val open_gifts : log:(string -> unit) -> (unit, string) result
val open_internet_list : log:(string -> unit) -> (unit, string) result
val choose_gift : log:(string -> unit) -> (unit, string) result
val leave_card : log:(string -> unit) -> (unit, string) result
val open_keyboard : log:(string -> unit) -> (unit, string) result
val dismiss_card : log:(string -> unit) -> (unit, string) result

val claim_code :
  log:(string -> unit) -> picture:Wire.box -> string -> (unit, string) result

val disconnect : unit -> unit
