(** Reader: the name plate over a locked-on wild Pokémon, and whether it shows
    the caught mark. Ported from PokemonLZA_CaughtMarkReader.cpp: its plate bar
    and caught mark reads.

    The plate's bar: in the upper 68% of the frame, the pixels of its green (red
    up to 90, green 175 and up, blue 90 to 145: the bar is about 45, 198, 115,
    and bright grass, 68, 160, 80, around the plate stays out), their blobs of
    150 pixels and up that are flat (80 wide or more, 24 high or less, at least
    4 times as wide as high, filling half their box or more); the widest. The
    player's own HP bar is about 63 wide; plates 105 to 115.

    The caught mark: in the box from 0.6 to 1.5 bar widths right of the bar's
    left edge and from 0.85 to 0.45 bar widths above its top, at least 34
    pinkish red pixels (red over 190 and over green by 70 and blue by 50, blue
    no more than 15 under green: the orange gender mark beside it is out) and 34
    white ones (every channel over 215); 15 each at 720p, 37 red and 42 white on
    the caught Mareep there.

    Where it differs: the mark's box follows the bar, and a probe's box is fixed
    when it is subscribed. So the mark takes two frames: the bar on one
    ({!probes}), then the box's two [core.line_shares@1] probes made from it
    ({!mark_probes}) on the next. *)

type bar = { x : float; y : float; w : float; h : float }
(** The bar's box, in pixels of the 1080p frame. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The bar's [core.find@1] probe. *)

val bar : Effects.measurements -> bar option
(** The widest flat bar; [None] with no plate. *)

val centre : bar -> float * float
(** The bar's centre, as fractions of the frame (the fork's target x and y). *)

val mark_probes : picture:Wire.box -> bar -> Wire.probe_spec list
(** The caught mark's two probes over its box above this bar. *)

val caught : Effects.measurements -> bar -> bool option
(** Whether {!mark_probes}' results for this bar show the mark: [false] when the
    mark's box is off the frame (no pixels to count, as the fork's); [None] when
    the results are missing. *)
