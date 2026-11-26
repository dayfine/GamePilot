(** Reader: the PC's item storage (PLAYER'S PC, ITEM STORAGE, WITHDRAW ITEM),
    from one frame. New, not in the fork, which never opens it. Placed from
    pokefirered item_pc.c ([sWindowTemplates], [ItemPc_BuildListMenuTemplate],
    [ItemPc_WithdrawMultipleInitWindow]) and measured on mGBA (2026-11-25):

    - the orange "WITHDRAW ITEM" label (window 2 at tile (1, 1)) shows on every
      screen of it: the list, the item's menu, the quantity box, its messages;
    - the list's arrow at x 57, rows 16 apart from y 10 (window 0 at (56, 8),
      cursor_X 1, upText_Y 2), six rows at most;
    - the quantity box, window 3 at tile (24, 15), white, while WITHDRAW asks
      how many.

    The item names, counts and the quantity are text
    ({!Frlg_text.Text_lines.item_pc_row}, [item_pc_count_digit],
    [item_pc_quantity_digit]). *)

val probes : Wire.probe_spec list

val shown : Effects.measurements -> bool option
(** The orange label fills at least {!min_label_share} of its box (x 8-39, y
    8-39). *)

val min_label_share : float
(** 0.4: the label's orange (231, 132, 41) fills 0.54 on mGBA; the PC menus
    over the overworld 0. *)

val label_orange : Color_count.range
(** Red 200..255, green 100..165, blue 0..80. *)

val cursor_row : Effects.measurements -> int option
(** The list's arrow row (0..5 of the shown rows) ({!Cursor_column} over x
    57-63 of each row). The arrow stays, hollow, while the item's menu or the
    quantity box shows. *)

val quantity_shown : Effects.measurements -> bool option
(** The quantity box: at least {!min_quantity_white} of x 194-229, y 124-147
    white (every channel 240 and over). *)

val min_quantity_white : float
(** 0.5: 0.84 with the box on mGBA, 0.11 without (the description's blue). *)

val rows : int
(** 6. *)
