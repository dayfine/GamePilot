(** Reader: where the Boxes' box title ("Box 8", "ボックス8", between the L and R
    buttons over the box) has its ink, left and right, in the pixels of the
    1080p frame. Ours: the fork reads no box title (its box programs start on
    the box the user picked).

    The title band (320, 336, 290, 34) holds the title alone, between the L
    button (x 240 to 272) and the R button (615 to 648); a column has ink when
    0.06 or more of its pixels are white (every channel over 200,
    {!Pixel_shares.white}). The title is centred and its digits are all as wide
    (the fork's English 1080p captures: "Box 5", "Box 7" and "Box 9" ink from
    411 to 476, "Box 15", "Box 24" and "Box 26" from 403 to 484), so a box
    number with one more digit inks 16 px wider. At 360p the fork's "Box 9"
    reads 410 to 474 and "Box 24" 401 to 480; console B's Japanese "ボックス8"
    (2026-11-26) 380 to 501, and within 3 px of that in every colour shift. The
    name tag over the cursor's cell covers the band's left or right end when the
    cursor is on the box's first row: read it with the cursor lower.

    Box names are the game's own ("Box N"): a renamed box reads as any other
    text. *)

type t = { left : int; right : int }
(** The first and last inked columns, in 1080p pixels. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The band's [core.line_shares@1] probe. *)

val read : Effects.measurements -> t option
(** Where the ink is; [None] with no inked column or no probe. Read it on the
    Boxes only ({!Boxes_screen}): a white fade inks the whole band. *)

val width : t -> int
(** From the first inked column to the last. *)

val same : t -> t -> bool
(** Both ends within 3 px: the same title, read twice. *)

val one_more_digit : before:t -> after:t -> bool
(** [after] inks 10 px or more wider than [before]: its box number has a digit
    more ("Box 32" after "Box 1"). A number ending in 0 after one ending in 1
    ("Box 10" after "Box 11") inks a few px wider, as a "1" is narrower than its
    place. *)
