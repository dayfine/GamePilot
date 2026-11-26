(** Reader: on-screen bright magenta/white 4-point sparkle star on Grand
    Underground tunnel walls (flashed for ~2.5s whenever the player pulses [R]
    radar).

    Measured from Console A captures ([run-47/frames/000038.jpg] and
    [run-49/frames/000005.jpg]): the sparkle star's halo sits in RGB
    [(200..255, 0..185, 200..255)] (25-220 pixels on 640x360, with zero
    background pixels in that range on brown tunnel floors/walls). A 3x3 grid
    around the centered player gives both horizontal ([dx]) and vertical ([dy])
    offset so the navigator can visually lock onto the exact sparkling tile. *)

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

val direction : Effects.measurements -> Corridor_nav.direction option
(** Dominant cardinal direction of the strongest visible sparkle star, if any.
*)
