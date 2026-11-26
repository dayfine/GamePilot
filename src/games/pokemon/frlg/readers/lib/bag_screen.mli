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

val cursor : Cursor_column.t
(** The six rows the list shows, left of the item names. *)

(** {1 Thresholds} *)

val min_arrow_share : float
(** A pocket arrow shows when this share of its box is the arrow's red.
    Measured: 0.16-0.24 with the arrow on Switch and mGBA, 0 without (also while
    a message or an item's action menu shows: the arrows hide). *)

val max_shadow_distance : float
(** {!item_menu} holds the bag's grey shadow within this distance of an even
    grey in channel shares (the fork's is_grey bound), tighter than the bag's
    0.25. Measured: 0 on the bag's mGBA and Switch frames, 0.023 at most with
    their colours shifted; One Island's harbor, whose sea passes 0.25, reads
    0.243-0.251, 0.219 at least shifted. *)

val min_box_sum : float
(** {!item_menu} holds the bag's shadow, underline and top frame each to at
    least this channel sum: a near-black box has no hue to read. Measured: 436
    at least on the bag's mGBA and Switch frames, 392 shifted; two Switch Start
    menu captures' near-black boxes 21, 33 at most shifted. *)

(** {1 Readers} *)

val bag_open : Effects.measurements -> bool

val item_menu : Effects.measurements -> bool
(** An item's own menu shows over the bag: the bag's shadow, underline and top
    frame show, but not the list's right frame, which the menu covers, nor
    either pocket arrow (they hide). The shadow must be grey within
    {!max_shadow_distance}, and each box at least {!min_box_sum} bright. *)

val pocket : Effects.measurements -> pocket option
(** While the bag shows; [None] for no arrow either side. *)

val cursor_row : Effects.measurements -> int option
(** The cursor's row of the six shown, 0 at the top, while the bag shows. A menu
    or a message over the list's bottom does not hide it. *)
