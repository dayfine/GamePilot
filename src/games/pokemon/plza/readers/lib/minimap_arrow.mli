(** Reader: the bearing the player faces, from the cyan arrow at the minimap's
    centre. Ported from PokemonLZA_DirectionArrowDetector.cpp ([plza/lean]),
    which [get_facing_direction] (PokemonLZA_BasicNavigation.cpp) reads for the
    AutoStory's [face_heading].

    In the box (0.076, 0.138, 0.031, 0.062) of the frame, the pixels OpenCV
    reads as cyan (hue 90 to 110 of 180, saturation and value 200 and over);
    their largest 4-connected blob, if 250 to 350 pixels (the arrow at 1080p;
    the bounds are not scaled, as the fork scales them, since the Switch capture
    is 1080p); the pixels inside its convex hull that are not the blob (the
    notch at the arrow's back); the direction away from them, from the blob's
    centre; the blob pixel furthest that way gives the bearing from the centre,
    clockwise from up (0 north on a north-up minimap).

    Where it differs: the daemon has no HSV probe, so each row of the box is a
    [core.line_shares@1] probe (its column shares are the row's pixels, 0 or 1)
    with the cyan written as linear tests (blue the largest channel and red the
    smallest, hue 180 to 221 degrees). Over every colour with blue 150 and up,
    they disagree with OpenCV's range on 2% of its cyans, all at its edges: hue
    90 where green tops blue by a hair (OpenCV rounds 179 degrees up), left out,
    and 110 and 111 by rounding at 221 degrees. And the hull is filled as a
    point-in-polygon test with its edges included, not cv::fillPoly's
    rasterising. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes, for a game picture at [picture] in the frame: one per row of the
    box. *)

val mask_of_rows : bool array array -> float option
(** The bearing from a mask (rows top to bottom, each a row of the box), as
    {!read} computes it; for tests. *)

val read : Effects.measurements -> float option
(** The bearing, in degrees, 0 to under 360; [None] when no arrow reads or a
    probe is missing. *)
