(** Reader: Grand Underground minimap orange/gold dig-spot sparkles.

    Measured from Console A captures ([run-24/frames/000001.jpg],
    [run-39/frames/000024.jpg], [run-42/frames/000300.jpg]): orange sparkle
    diamonds on the top-left minimap sit in RGB [(200..255, 110..215, 0..80)].
    Probes split the right half of the central Hideaway ring into three zones
    (starting East of the player dot at [x = 0.114] so the player's own dot
    never false-positives):
    - [bottom_east]: horizontal corridor East of the South doorway
    - [east_vertical]: vertical corridor along the East outer wall
    - [top_east]: horizontal corridor West from the NE corner to the North
      doorway *)

type nearby = {
  bottom_east : bool;
      (** At least one orange sparkle in the bottom-East corridor. *)
  east_vertical : bool;
      (** At least one orange sparkle along the East vertical corridor. *)
  top_east : bool;  (** At least one orange sparkle in the top-East corridor. *)
}
(** Active nearby dig-spot summary read from the minimap. *)

val none : nearby
(** No sparkles in any of the three zones. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The three [color_count_probe] specs for the ring corridor strips. *)

val read : Effects.measurements -> nearby
(** Read whether orange dig-spot sparkles are visible in each strip. *)

val any : nearby -> bool
(** [true] when at least one of the three corridor strips has a sparkle. *)

val to_string : nearby -> string
(** Short summary, e.g. ["bottom_east, top_east"] or ["none"]. *)
