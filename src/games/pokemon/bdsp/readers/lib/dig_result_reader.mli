(** Reader: post-dig item spotlight screen ([獲得了 ...！]) after a Grand
    Underground mining wall finishes or collapses.

    Measured from Console A capture [run-60/frames/000093.jpg]: each uncovered
    treasure is displayed centered at [(x=0.50, y=0.50)] inside a uniform tan
    spotlight oval ([RGB ~(193, 184, 141)] at [x=0.36..0.44] and
    [x=0.56..0.64]). Color shares inside the center icon box classify Mysterious
    Shards (pink/magenta crystal, S vs L by area), Spheres (blue/red/green),
    Statue Boxes (gold/yellow), and Other treasures. *)

open Bdsp_underground

val probes : picture:Wire.box -> Wire.probe_spec list
(** Spotlight-oval and center-icon probes for post-dig item classification. *)

val on_item_spotlight : Effects.measurements -> bool
(** [true] when the uniform tan item-reward spotlight oval is visible. *)

val read : Effects.measurements -> Mining_counters.treasure option
(** Classify the treasure shown on the current post-dig spotlight screen, or
    [None] if no spotlight screen is visible. *)

val treasure_name : Mining_counters.treasure -> string
(** Short human-readable label for logs. *)
