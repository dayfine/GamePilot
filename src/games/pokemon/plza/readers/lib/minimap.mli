(** Reader: which recorded minimap the top-left minimap shows, as the fork pins
    a checkpoint's start ([matching_minimap] in
    Inference/Map/PokemonLZA_MinimapMatch.cpp, [plza/lean]). The box is 132 px
    square at (52, 55) on 1280x720 (as fractions of the frame), in 16 x 16 cells
    each read as its mean colour; only the ring of cells whose centres lie 22 to
    62 of the 66 px half width from the middle is compared (148 cells: outside
    the player's arrow, inside the rim's icons). Each channel of the ring is
    scaled to the reference's mean (by 0.5 to 2), then compared by the root mean
    square of the summed squared channel differences; the nearest reference
    within 30 is the reading ({!Minimap_references}). The fork measured 2.2 to
    21.9 on 03.04's start darkened or brightened 20%, 37 moved one cell, 47.5
    and up on 946 other frames of Main Mission 03.

    Where it differs: the fork averages each cell over the frame it is given;
    the daemon gives each cell's mean on the 1080p frame. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** A [core.color_stats@1] probe per ring cell, for a game picture at [picture]
    in the frame. *)

val reference_names : string list
(** The references that parsed: all of {!Minimap_references.all}. *)

val distances : Effects.measurements -> (string * float) list option
(** Each reference's distance from the ring; [None] when a probe is missing. *)

val read : Effects.measurements -> string option
(** The nearest reference within 30; [None] when none is, or a probe is missing.
*)
