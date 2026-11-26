(** The claimed gifts' box slots read on the Boxes, and a gift that landed in
    party slot 6 moved to its slot, from the main menu back to it (moves and
    timings as run on console B, 2026-11-20 and 25).

    Row 0 (Boxes), A (2.5 s), and A (1.5 s) past the first-time "Your Boxes"
    card only when the Boxes do not show ({!Plza_readers.Boxes_screen}). The
    cursor is then on Box 1 slot 1. A slot is read by moving to it (Right and
    Down, each 80 ms, released 250), reading the cell held 1 s within 2 s
    ({!Plza_readers.Box_cell}) and moving back.

    A gift in party slot 6: the main menu's sixth party card must hold a Pokémon
    before ({!Plza_readers.Main_menu_row.card_green}); its slot is read empty,
    then Up, Right five times to the party's sixth slot, Y (400 ms), Down, Left
    to the slot's column, Y (600 ms), and the cell under the cursor read. After
    B (1.5 s) out of the Boxes, the sixth card must be empty and the fifth still
    hold one.

    Only Box 1 is read, and a gift is moved only to its first row (slots 1 to 6,
    as on console B); reading rows below it is ours, not yet run on a console.
    The probes must be subscribed ({!Mystery_gift.probes}). *)

(** What a slot read. *)
type slot_read =
  | Filled  (** A Pokémon is there. *)
  | Empty  (** No Pokémon is there. *)
  | Not_read of string  (** Why it was not read, or the gift not moved. *)

val check :
  log:(string -> unit) ->
  party_gift:Plza_gift_catalog.Gift_catalog.box_slot option ->
  in_box:Plza_gift_catalog.Gift_catalog.box_slot list ->
  ((Plza_gift_catalog.Gift_catalog.box_slot * slot_read) list, string) result
(** From the main menu: each of [in_box] read, then the gift in party slot 6
    (when [party_gift] names its slot) moved there and read; each slot with what
    it read. [Error] when the Boxes or the main menu do not show, or the party's
    cards are not as above. *)
