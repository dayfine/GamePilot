(** Readers: FireRed's white text box, its advance arrow, and the Yes/No box
    that comes with a question. Ported from the fork's
    Inference/Dialogs/PokemonFRLG_DialogDetector (WhiteDialogDetector,
    AdvanceWhiteDialogDetector, SelectionDialogDetector); the boxes are theirs,
    relative to the game picture.

    The box is white inside a light blue frame across the bottom quarter of the
    screen. Thin probes along its inner right, top and bottom edges must be
    white, and the frame line above it must not be (a white wall, like the S.S.
    Anne's hull, is white there too). *)

val probes : Wire.probe_spec list
(** Every probe the three readers need. *)

(** {1 Thresholds} *)

val frame_min_white_sum : float
(** The frame line counts as white from this channel sum: above the light blue
    frame's (603-686 measured on Switch and mGBA dialogs), below a white wall's
    765. {!dialog_up} wants the frame line below it, flat or not: a fade to
    white leaves the line near white but not flat. *)

val min_red_excess : float
(** The arrow is red: the text area's pixels in the arrow's color range ((164,
    0, 0) to (255, 114, 87), the fork's) have a mean red channel more than this
    above both green and blue (the fork's 160). Measured: 207.8 or more with the
    arrow on Switch and mGBA alike; a box without one has no pixel in range
    (black text and its grey shadow are outside it). *)

(** {1 Readers} *)

val dialog_up : Effects.measurements -> bool
(** The white text box shows. *)

val advance_arrow : Effects.measurements -> bool
(** The white text box shows with its red arrow: the page is done and A turns
    it. One [core.color_count@1] probe over the text area, as the fork filters
    that area to the arrow's red. Red text reads as an arrow too, as in the
    fork. *)

val selection_dialog : Effects.measurements -> bool
(** The white text box shows with a Yes/No box above its right end. Unlike the
    fork, the frame test of {!dialog_up} applies too: a white fade is not a
    question. *)
