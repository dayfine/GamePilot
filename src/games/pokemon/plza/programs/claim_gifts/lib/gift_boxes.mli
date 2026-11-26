(** The Pokémon gifts put in their catalog slots in Box 1 and read there, from
    the main menu back to it: Row 0 (Boxes), A (2.5 s), and A (1.5 s) past the
    first-time "Your Boxes" card only when the Boxes do not show
    ({!Plza_readers.Boxes_screen}) and the card does
    ({!Plza_readers.Tutorial_card}, ours: no capture of that card was kept); B
    (1.5 s) out (console B, 2026-11-20 and 25). Whether party slot 6 holds a
    Pokémon is read on the main menu's sixth card first
    ({!Plza_readers.Main_menu_row}).

    The Boxes open on the box last looked at, the cursor on its first slot. The
    cursor goes down a row ({!Box_cursor}) and L and R go to Box 1
    ({!Box_paging}). Each gift's slot is read there; a gift whose slot reads
    empty is looked for, in the order given:

    - party slot 6, when it holds a Pokémon: carried to the first such slot;
    - the box the Boxes opened on, when it is not Box 1: each of its 30 cells
      read, and when it holds exactly as many Pokémon as gifts still missing,
      each carried, in reading order, to the next missing gift's slot, by way of
      party slot 6 (box to party slot 6, L to Box 1, party slot 6 to the slot, R
      back), as only the party-box move has been run on a console.

    Then every gift's slot is read again, last. A gift is known by where the
    game puts it, not by its species (no reader for that yet): received into a
    party of five, it lands in party slot 6, and into a full party in the first
    empty cells of the box the Boxes open on, in the order received. A Pokémon
    in a gift's slot counts as that gift. So party slot 6 must hold no Pokémon
    of the player's but a gift, and the box the Boxes open on none of theirs:
    the guide asks for both. Ours: the fork has no Mystery Gift program. *)

(** What a slot read. *)
type slot_read = Box_cursor.cell =
  | Filled  (** A Pokémon is there. *)
  | Empty  (** No Pokémon is there. *)
  | Not_read of string  (** Why it was not read. *)

type arranged = {
  reads : (Plza_gift_catalog.Gift_catalog.box_slot * slot_read) list;
      (** Each gift's slot as read last, in the order given. *)
  moved : int;  (** The Pokémon carried into a gift's slot. *)
}
(** What came of it. *)

val arrange :
  log:(string -> unit) ->
  Plza_gift_catalog.Gift_catalog.box_slot list ->
  (arranged, string) result
(** From the main menu: the gifts' slots, in the order their gifts were received
    (a slot outside Box 1 is [Not_read]), made true as above. [Error] when the
    Boxes, a box title or the main menu do not show, or party slot 6 reads
    neither holding a Pokémon nor empty. *)
