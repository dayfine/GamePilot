(** The Boxes opened on Box 1, a gift in party slot 6 moved to its slot there,
    and the gifts' slots read, from the main menu back to it: Row 0 (Boxes), A
    (2.5 s), and A (1.5 s) past the first-time "Your Boxes" card only when the
    Boxes do not show ({!Plza_readers.Boxes_screen}) and the card does
    ({!Plza_readers.Tutorial_card}, ours: no capture of that card was kept); B
    (1.5 s) out (console B, 2026-11-20 and 25). Whether party slot 6 holds a
    Pokémon is read on the main menu's sixth card first
    ({!Plza_readers.Main_menu_row}).

    The Boxes open on the box last looked at, the cursor on its first slot. The
    cursor goes down a row ({!Box_cursor}) and L to Box 1 ({!Box_paging}); its
    title is read as Box 1 before any slot is read or any Pokémon moved. Each
    gift's slot is read; when party slot 6 holds a Pokémon, it is carried to the
    first slot read empty, and every slot read again; B leaves. Leaving the
    Boxes on Box 1 makes it the box they open on next, where the game puts a
    gift received into a full party.

    A gift is known by where the game puts it, not by its species (no reader for
    that yet): received into a party of five, a gift lands in party slot 6, the
    first received first, so the Pokémon there is taken for the first gift whose
    slot is empty, and a Pokémon in a gift's slot counts as that gift. Party
    slot 6 must so hold no Pokémon of the player's but a gift: the guide asks
    for it. Ours: the fork has no Mystery Gift program. *)

(** What a slot read. *)
type slot_read = Box_cursor.cell =
  | Filled  (** A Pokémon is there. *)
  | Empty  (** No Pokémon is there. *)
  | Not_read of string  (** Why it was not read. *)

type settled = {
  reads : (Plza_gift_catalog.Gift_catalog.box_slot * slot_read) list;
      (** Each gift's slot as read last, in the order given. *)
  moved : bool;  (** Party slot 6's Pokémon was carried into a gift's slot. *)
}
(** What came of it. *)

val settle :
  log:(string -> unit) ->
  Plza_gift_catalog.Gift_catalog.box_slot list ->
  (settled, string) result
(** From the main menu: the gifts' slots, in the order their gifts are received
    (a slot outside Box 1 is [Not_read]), settled as above. [Error] when the
    Boxes, Box 1's title or the main menu do not show, or party slot 6 reads
    neither holding a Pokémon nor empty. *)
