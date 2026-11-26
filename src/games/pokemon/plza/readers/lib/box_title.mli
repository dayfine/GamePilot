(** Reader: the Boxes' box title ("Box 1", "ボックス1", between the L and R buttons
    over the box) as its glyphs' ink, left to right, in the pixels of the 1080p
    frame, and whether it names Box 1. Ours: the fork reads no box title (its
    box programs start on the box the user picked).

    The title band (320, 336, 290, 34) holds the title alone, between the L
    button (x 240 to 272) and the R button (615 to 648); a column has ink when
    0.06 or more of its pixels are white (every channel over 200,
    {!Pixel_shares.white}), and a glyph is a run of inked columns, as wide as
    its columns cover. The title is the box's number after a word, and a "1" is
    a narrow stroke: Box 1's title ends in a glyph 3 to 10 px wide and at most
    0.6 as wide as the glyph before it. Measured on console B (2026-11-26,
    Japanese, the probe's own 1080p readings while L paged boxes 8 to 1 and
    round): "1" 9 px after "ス" 25 (0.36), the other digits 16 to 18 (0.64 to
    0.72); at 360p (console B's frames) 6 after 24 and 15 after 24; the fork's
    English 1080p captures: "1" 7 px after "x" 12 (0.58), the other digits 11 to
    13 after "x" or a digit (0.85 or more), and at 360p "4" 9 after "2" 12. "Box
    11" ends in two "1"s (1.0); "Box 21" and "Box 31" would read as Box 1:
    console B's game has 8 boxes. The name tag over the cursor's cell covers the
    band's ends when the cursor is on the box's first row: read it with the
    cursor lower.

    Box names are the game's own: a renamed box reads as any other text. *)

type t = { glyphs : (int * int) list }
(** Each glyph's first and last inked column, left to right, in 1080p pixels. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The band's [core.line_shares@1] probe. *)

val read : Effects.measurements -> t option
(** The glyphs; [None] with no inked column or no probe. Read it on the Boxes
    only ({!Boxes_screen}): a white fade inks the whole band. *)

val same : t -> t -> bool
(** The first glyph's left end, the last glyph's ends, within 3 px: the same
    title, read twice. *)

val box_one : t -> bool
(** The title names Box 1, as above. *)

val text : t -> string
(** Its glyphs' widths, for a log line ("20 25 25 9"). *)
