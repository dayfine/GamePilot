(** Where the PC's item storage prints its text, in game pixels: pokefirered
    item_pc.c, measured on mGBA (2026-11-25). New, not in the fork. *)

val row : int -> Text_lines.t
(** Row [i] (0..5) of the PC's item storage list (WITHDRAW ITEM): item names and
    CANCEL. pokefirered item_pc.c, [ItemPc_BuildListMenuTemplate]: list window 0
    at tile (7, 1), names at x 9 of it (x 65), rows 16 apart, the first's glyph
    cell at y 10. Read right on mGBA (2026-11-25). *)

val count_digit : int -> int -> Text_lines.t
(** [count_digit row k]: digit [k], counted from the right (0: ones), of the
    count on item storage row [row]: item_pc.c [ItemPc_ItemPrintFunc] prints
    ["×<count>"] (right aligned in 3 cells) in the small font at x 110 of the
    list window, so the ones digit starts at x 184. *)

val quantity_digit : int -> Text_lines.t
(** Digit [k] (0: hundreds) of WITHDRAW's quantity box: item_pc.c
    [UpdateWithdrawQuantityDisplay] prints ["×NNN"] (leading zeros) in the small
    font at (8, 10) of window 3, at tile (24, 15): measured on mGBA
    (2026-11-25), the digits' cells from x 208, 5 apart, their top at y 130. *)
