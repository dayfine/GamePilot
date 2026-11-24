(** Readers: the bag, its open pocket and its cursor row. The screen test is the
    fork's Menus/PokemonFRLG_BagDetector (the bag's grey shadow, the pocket
    name's orange underline, the list's yellow frame along its top and right);
    the cursor is the fork's read_item_list_cursor_row
    (Menus/PokemonFRLG_ItemListReader), through {!Cursor_column}.

    The pocket is not in the fork, which counts its presses instead. The bag
    shows a red arrow beside it toward each pocket it can turn to: Items, the
    first, has only the right one; Key Items both; Poké Balls, the last, only
    the left one. *)

type pocket = Items | Key_items | Poke_balls

val pocket_name : pocket -> string
val probes : Wire.probe_spec list

val item_menu_probes : Wire.probe_spec list
(** {!item_menu}'s own, with {!probes}: apart, so the battle's and the walk's
    probe sets (and their recorded wire logs) stay as they were. *)

val cursor : Cursor_column.t
(** The six rows the list shows, left of the item names. *)

(** {1 Thresholds} *)

val min_arrow_share : float
(** A pocket arrow shows when this share of its box is the arrow's red.
    Measured: 0.16-0.24 with the arrow on Switch and mGBA, 0 without (also while
    a message or an item's action menu shows: the arrows hide). *)

(** {1 Readers} *)

val bag_open : Effects.measurements -> bool

val item_menu : Effects.measurements -> bool
(** An item's action menu (USE, GIVE, TOSS, CANCEL) over the bag: the pocket
    name's underline and the list's top frame show, the menu's white right of
    its options, and no pocket arrow. Not {!bag_open}: the menu covers the
    bottom of the list's right frame (the fork's BagDetector reads the bag as
    closed then too). *)

val pocket : Effects.measurements -> pocket option
(** While the bag shows; [None] for no arrow either side. *)

val cursor_row : Effects.measurements -> int option
(** The cursor's row of the six shown, 0 at the top, while the bag shows. A menu
    or a message over the list's bottom does not hide it. *)
