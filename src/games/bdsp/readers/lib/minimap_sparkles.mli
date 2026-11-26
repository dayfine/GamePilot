(** Reader: Grand Underground minimap orange/gold dig-spot sparkles.

    Measured from Console A captures ([run-24/frames/000001.jpg],
    [run-24/frames/000013.jpg], [run-39/frames/000024.jpg]): orange sparkle
    diamonds on the top-left minimap sit in RGB [(200..255, 110..215, 0..80)].
    Probes split the L-corridor outside the central Hideaway doorway into its
    horizontal East corridor and vertical North corridor so the runner can run
    straight past empty segments. *)

type nearby = {
  east_corridor : bool;
      (** At least one orange sparkle along the horizontal East corridor. *)
  north_corridor : bool;
      (** At least one orange sparkle along the vertical North corridor. *)
}
(** Active nearby dig-spot summary read from the minimap. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The two [color_count_probe] specs for the nearby corridor strips. *)

val read : Effects.measurements -> nearby
(** Read whether orange dig-spot sparkles are visible in each strip. *)

val any : nearby -> bool
(** [true] when at least one nearby corridor strip has a sparkle. *)
