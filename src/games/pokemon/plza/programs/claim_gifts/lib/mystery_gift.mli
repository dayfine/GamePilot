(** The Mystery Gift screens' presses and waits, as run on console B
    (2026-11-20). The screens are read by {!Plza_readers.Mystery_gift_screen}
    and the code keyboard by {!Switch_home.Code_keyboard}; their probes must be
    subscribed ({!probes}).

    - {!open_gifts}: from the main menu, row 5 (Link Play), A (2 s); Right,
      Right, Down (each 80 ms, released 300) to Mystery Gift; A (2 s).
    - {!open_internet_list}: A (1.5 s), A (4 s) to connect, then A (2 s) until
      the gift list is active, 25 at most.
    - {!choose_gift}: Down from the selected item to the gift's (found by its
      name, {!Plza_readers.Mystery_gift_screen.gift_item}), the cursor read on
      it, then A (8 s).
    - {!leave_list}: B (1.5 s) and A (2 s): "stop for now?", yes.
    - {!open_keyboard}: Down, A (2 s); A (2 s) until the keyboard opens, 25 at
      most.
    - {!enter_code}: the code typed; + (5 s); the list again; A (8 s) on the
      code's gift.
    - {!dismiss_card}: A (3 s) past a gift's card.
    - {!disconnect}: B (1.5 s), A (4.5 s): "you will be disconnected", yes; A
      (2.5 s); B (2 s): back on the main menu.

    The list and the keyboard count once they have read so for 1 s (a white fade
    reads as the list for a moment). Ours: the fork's PLZA programs have no
    Mystery Gift. *)

val probes :
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  gift_name:string option ->
  Wire.probe_spec list
(** The main menu's, the gift screens', the keyboard's, the Boxes' (and their
    cursor's cell's) and the SAVE dialog's probes; [gift_name] the uploaded
    template of an Internet gift's name in the game's language, [None] for a
    gift claimed by code. *)

val open_gifts : log:(string -> unit) -> (unit, string) result
(** From the main menu: to the Link Play row, A, Right twice, Down, A, onto the
    Mystery Gift menu. *)

val open_internet_list : log:(string -> unit) -> (unit, string) result
(** "Get with Internet" and connect (A, A); the gift list must show, A pressed
    while it does not. *)

val choose_gift : log:(string -> unit) -> (unit, string) result
(** Down from the selected item to the gift's, which must be listed below it and
    be reached, then A to claim it. [Error] before A when the gift is not
    listed. *)

val leave_list : unit -> unit
(** B and yes to "stop for now?": from the gift list to the Mystery Gift menu.
*)

val open_keyboard : log:(string -> unit) -> (unit, string) result
(** Down and A on the Mystery Gift menu; the code keyboard must show, A pressed
    while it does not. *)

val enter_code :
  log:(string -> unit) -> picture:Wire.box -> string -> (unit, string) result
(** Types the code ({!Switch_home.Code_keyboard.type_code}), + (5 s); the gift
    list must show, then A claims the code's gift. *)

val card_shown : Effects.measurements -> bool
(** A gift's card: the gift was received. *)

val describe : Effects.measurements -> string
(** The gift screens' readings, for a log line. *)

val dismiss_card : unit -> unit
(** A past a gift's card. *)

val disconnect : unit -> unit
(** B, yes to "you will be disconnected", A, B: off the link, back on the main
    menu, no read. *)
