(** Reader: the advance chevron at the bottom right of a dialogue box or of
    boxless subtitles (the screen's [advance_arrow] reading). Ported from
    PokemonLZA_StoryDialogDetector.cpp: in the box x 1370-1480, y 930-1050 of
    the 1080p frame, a blob of white (red and green 235 up, blue 220 up) or of
    dark (every channel 110 at most) pixels, 26-40 wide and 15-24 high, 1.4 to
    2.1 times as wide as high, with its colour around it (within 4 pixels) at
    most 9% of its own pixels (its stray share), and overlapping the chevron's
    V. The daemon finds the blobs and scores both ([core.find@1]'s margin and
    shape).

    Where it differs, for another capture's colours (a frame a tenth dimmer): a
    third range, white from 215 (blue 200), and an overlap of 0.51 at least, not
    0.45; the fork's own notes put chevrons at 0.51 up and the closest other
    shape at 0.48. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The probe {!shown} needs, for a game picture at [picture] in the frame. *)

val shown : Effects.measurements -> bool
(** A blob passes every test. [false] when the probe is missing. *)
