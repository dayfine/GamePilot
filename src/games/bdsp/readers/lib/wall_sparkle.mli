(** Reader: on-screen bright white-gold 4-point sparkle star on Grand
    Underground tunnel walls (flashed for ~2.5s whenever the player pulses [R]
    radar).

    Measured from Console A capture [run-59/frames/000079.jpg]: the sparkle
    star's pure-white core sits in RGB [(240..255, 245..255, 235..255)] (~30
    pixels on 640x360), whereas static orange wall torches have <= 13 pixels in
    that range and cancel out completely under {!locate_diff}. A 3x3 grid around
    the player gives both horizontal ([dx]) and vertical ([dy]) offset so the
    navigator can visually lock onto the exact sparkling tile. *)

open Bdsp_underground

type offset = {
  dx : int;  (** [-1] = left (West), [0] = aligned, [+1] = right (East). *)
  dy : int;  (** [-1] = above (North), [0] = aligned, [+1] = below (South). *)
}
(** Coarse 3x3 screen offset of the strongest visible sparkle star relative to
    the player. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The 9 [color_count_probe] specs (3x3 grid around the player, excluding the
    top-left minimap). *)

val locate : Effects.measurements -> offset option
(** Screen offset of the strongest visible sparkle star, if any. *)

val locate_diff :
  before:Effects.measurements -> after:Effects.measurements -> offset option
(** Screen offset of the cell whose sparkle-star share increased most from
    [before] (pre-radar) to [after] (post-radar), cancelling static wall
    torches. *)

val direction : Effects.measurements -> Corridor_nav.direction option
(** Dominant cardinal direction of the strongest visible sparkle star, if any.
*)
