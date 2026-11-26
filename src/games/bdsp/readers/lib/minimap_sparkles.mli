(** Reader: Grand Underground minimap orange/gold dig-spot sparkles.

    Measured from Console A captures ([run-24/frames/000001.jpg] and
    [run-24/frames/000013.jpg]): orange sparkle diamonds on the top-left minimap
    sit in RGB [(200..255, 110..215, 0..80)]. Probes cover the North-East and
    South-East corridor strips adjacent to the central Hideaway doorway. *)

(** Active nearby dig-spot summary read from the minimap. *)
type nearby = {
  north_east : bool;  (** At least one orange sparkle North-East of the doorway. *)
  south_east : bool;  (** At least one orange sparkle South-East of the doorway. *)
}

val probes : picture:Wire.box -> Wire.probe_spec list
(** The two [color_count_probe] specs for the nearby corridor strips. *)

val read : Effects.measurements -> nearby
(** Read whether orange dig-spot sparkles are visible in each strip. *)

val any : nearby -> bool
(** [true] when at least one nearby corridor strip has a sparkle. *)
