(** Reader: on-screen bright magenta/white 4-point sparkle star on Grand
    Underground tunnel walls.

    Measured from Console A captures ([run-47/frames/000038.jpg] and
    [run-49/frames/000005.jpg]): the sparkle star's halo sits in RGB
    [(200..255, 0..185, 200..255)] (25-220 pixels on 640x360, with zero
    background pixels in that range on brown tunnel floors/walls). Four
    directional boxes around the player tell the navigator which wall holds the
    active dig spot without blind zig-zag probing. *)

open Bdsp_underground

val probes : picture:Wire.box -> Wire.probe_spec list
(** The four directional [color_count_probe] specs (North, South, East, West of
    the player), excluding the top-left minimap. *)

val direction : Effects.measurements -> Corridor_nav.direction option
(** Direction of the strongest visible wall sparkle star, if any. *)
