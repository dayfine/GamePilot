(** Moving the gift in party slot 6 to Box 1 slot 2 and saving: stage 3 of
    [plza_claim_and_bank.sh] from the BDSPLab lab tools (console B, 2026-11-20).
    From the main menu (open): row 0 (Boxes), A (2.5 s), A (1.5 s) past the
    first-time "Your Boxes" card; Up, Right five times (each 80 ms, released
    250) to the party's sixth slot, Y (400 ms); Down, Left four times to Box 1
    slot 2 (Xerneas, the code's gift, in slot 1), Y (600 ms); B (1.5 s) out of
    the Boxes; R (1.5 s), A (3.5 s), A (1.5 s): Save Progress; B (1.5 s) closes
    the menu. The main menu's probes must be subscribed
    ({!Plza_readers.Main_menu_row.probes}).

    Where it differs: the menu's party cards are read before and after
    ({!Plza_readers.Main_menu_row.card_green}): the sixth must hold a Pokémon
    before the move and none after it, the fifth one still, or the move is an
    error and nothing is saved. The Boxes are read after the first A
    ({!Plza_readers.Boxes_screen}), and the second A pressed only when they do
    not show (console B, 2026-11-25: no first-time card). The SAVE dialog is
    read ({!Plza_readers.Save_dialog}), and the save counts only when its "Last
    Saved" changed: after A, A, R opens the dialog again to read it, and B
    closes it before the script's B. The stage is four calls, so a run can start
    or stop between them ({!Claim_gifts}). *)

val to_boxes : log:(string -> unit) -> (unit, string) result
(** Row 0, the sixth card read, and into the Boxes, past the first-time card
    when it shows. *)

val await_boxes : unit -> (unit, string) result
(** The Boxes screen, read for 1 s within 2 s, no press. *)

val await_dialog : unit -> (unit, string) result
(** The SAVE dialog, read for 1 s within 3 s, no press. *)

val move_gift : log:(string -> unit) -> (unit, string) result
(** From the Boxes: the move, B, the cards read. *)

val open_save_prompt : log:(string -> unit) -> (unit, string) result
(** From the main menu: R, the SAVE dialog read. *)

val save : log:(string -> unit) -> (unit, string) result
(** On the SAVE dialog: its "Last Saved" read; A, A; the main menu read; R again
    and "Last Saved" read again; B, B. [Error] when it did not change. *)
