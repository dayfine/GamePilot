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
    error and nothing is saved. The save itself is not read (no capture of it
    yet). The stage is four calls, so a run can start or stop between them
    ({!Claim_gifts}). *)

val to_boxes : log:(string -> unit) -> (unit, string) result
(** Row 0, the sixth card read, and into the Boxes. *)

val move_gift : log:(string -> unit) -> (unit, string) result
(** From the Boxes: the move, B, the cards read. *)

val open_save_prompt : log:(string -> unit) -> (unit, string) result
(** From the main menu: R, Save Progress's prompt. *)

val save : log:(string -> unit) -> (unit, string) result
(** On the prompt: A, A, B. Not read. *)
