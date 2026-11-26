(** Reader: the name plate over a locked-on wild Pokémon, and whether it shows
    the caught mark. Ported from PokemonLZA_CaughtMarkReader.cpp: its plate bar
    and caught mark reads.

    The plate's bar: in the upper 68% of the frame, the pixels of its green (red
    up to 90, green 175 and up, blue 90 to 145: the bar is about 45, 198, 115,
    and bright grass, 68, 160, 80, around the plate stays out), their blobs of
    150 pixels and up that are flat (80 wide or more, 24 high or less, at least
    4 times as wide as high, filling half their box or more); the widest. The
    player's own HP bar is about 63 wide; plates 105 to 115.

    The caught mark: the Poke Ball in the box from 0.6 to 1.5 bar widths right
    of the bar's left edge and from 0.85 to 0.45 bar widths above its top (the
    fork's box): a red blob at least 1.4 times as wide as high (its red half)
    with a white blob under it (its white half, below a black band). Red is red
    160 and up, green up to 150 and blue up to 170; white every channel 200 and
    up; blobs of 40 pixels and up.

    Where it differs: the fork counts the box's pinkish red pixels (red over
    190, over green by 70 and blue by 50, blue no more than 15 under green) and
    white ones (every channel over 215), at least 15 each at 720p. The female
    mark is a pinkish red disc round a white sign, which those counts take for
    the ball: at 1080p on console B (2026-11-25) a female Weedle or Scatterbug
    with no ball counted 49 to 101 red and 23 to 82 white against the bound 34,
    so 03.10 and 03.11 read most plates as caught and threw at none; a caught
    Bunnelby counted 121 red and 223 to 262 white. Here the ball is told by its
    shape instead: the disc is not flat, and its sign sits inside its red, not
    under it. The ranges are wider than the fork's so that a 640x360 frame's
    blurred ball still reads.

    The mark's box follows the bar, and a probe's box is fixed when it is
    subscribed. So the mark takes two frames: the bar on one ({!probes}), then
    the box's [core.find@1] probe made from it ({!mark_probes}) on the next. *)

type bar = { x : float; y : float; w : float; h : float }
(** The bar's box, in pixels of the 1080p frame. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The bar's [core.find@1] probe. *)

val bar : Effects.measurements -> bar option
(** The widest flat bar; [None] with no plate. *)

val centre : bar -> float * float
(** The bar's centre, as fractions of the frame (the fork's target x and y). *)

val mark_probes : picture:Wire.box -> bar -> Wire.probe_spec list
(** The caught mark's probe over its box above this bar: its red and white
    blobs. *)

val caught : Effects.measurements -> bar -> bool option
(** Whether {!mark_probes}' result for this bar shows the ball: [false] when the
    mark's box is off the frame (no pixels to count, as the fork's); [None] when
    the result is missing. *)
