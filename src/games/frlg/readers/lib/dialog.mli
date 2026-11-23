(** Readers: FireRed's white text box, its advance arrow, and the Yes/No box
    that comes with a question. Ported from the fork's
    Inference/Dialogs/PokemonFRLG_DialogDetector (WhiteDialogDetector,
    AdvanceWhiteDialogDetector, SelectionDialogDetector); the boxes are theirs,
    relative to the game picture.

    The box is white inside a light blue frame across the bottom quarter of the
    screen. Thin probes along its inner right, top and bottom edges must be
    white, and the frame line above it must not be (a white wall, like the S.S.
    Anne's hull, is white there too). *)

val probes : Game_screen.t -> Wire.probe_spec list
(** Every probe the three readers need. *)

(** {1 Thresholds} *)

val frame_min_white_sum : float
(** The frame line counts as white from this channel sum: above the light blue
    frame's (603-686 measured on Switch and mGBA dialogs), below a white wall's
    765. *)

val min_red_excess : float
(** The arrow is red: a strip holding it has a mean red channel at least this
    far above both green and blue. Measured: 19.4 or more in the strip with the
    arrow, at most 0 in every strip of a box without one (black text and its
    grey shadow add nothing), on Switch and mGBA alike. *)

(** {1 Readers} *)

val dialog_up : Effects.measurements -> bool
(** The white text box shows. *)

val advance_arrow : Effects.measurements -> bool
(** The white text box shows with its red arrow: the page is done and A turns
    it. The arrow sits right after the last word, so it is searched in
    overlapping strips along both text lines. Red text reads as an arrow too, as
    in the fork. *)

val selection_dialog : Effects.measurements -> bool
(** The white text box shows with a Yes/No box above its right end. Unlike the
    fork, the frame test of {!dialog_up} applies too: a white fade is not a
    question. *)
