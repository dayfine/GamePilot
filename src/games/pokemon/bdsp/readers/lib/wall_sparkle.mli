(** Reader: on-screen bright white-gold 4-point sparkle star on Grand
    Underground tunnel walls (flashed for ~2.5s whenever the player pulses [R]
    radar).

    Uses [core.find@1] blob-diffing over the playfield (excluding the top-left
    minimap) in RGB [(240..255, 230..255, 180..255)]. Comparing post-radar blobs
    against pre-radar blobs cancels static wall torches and player highlights at
    pixel precision without masking neighboring stars, and returns the star's
    exact normalized screen offset relative to the player [(0.50, 0.48)]. *)

open Bdsp_underground

type offset = {
  dx : int;  (** [-1] = left (West), [0] = aligned, [+1] = right (East). *)
  dy : int;  (** [-1] = above (North), [0] = aligned, [+1] = below (South). *)
  dx_norm : float;
      (** Normalized X offset from player center ([0.50]); positive = East. *)
  dy_norm : float;
      (** Normalized Y offset from player center ([0.48]); positive = South. *)
}
(** Exact and coarse screen offset of the strongest visible sparkle star
    relative to the player. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The two [core.find@1] probes covering the playfield outside the top-left
    minimap. *)

val locate : Effects.measurements -> offset option
(** Screen offset of the strongest visible sparkle star, if any. *)

val locate_diff :
  before:Effects.measurements -> after:Effects.measurements -> offset option
(** Screen offset of the strongest new sparkle-star blob in [after] that was not
    present within [35] game pixels in [before], cancelling static wall torches.
*)

val direction : Effects.measurements -> Corridor_nav.direction option
(** Dominant cardinal direction of the strongest visible sparkle star, if any.
*)
