(** [core.color_count@1] probes as the readers use them: a color range given
    channel by channel, and the share of a box's pixels inside it. *)

type channels = { r : int; g : int; b : int }
(** One color, 0..255 per channel. *)

type range = { low : channels; high : channels }
(** Both ends included. *)

val probe : id:string -> Wire.box -> range -> Wire.probe_spec
(** Over a box of the game picture, every frame. *)

val share : Effects.measurements -> string -> float option
(** The share of the box's pixels in range; [None] when the probe is missing or
    of another kind ({!Switch_home.Color_share.read}). *)

val mean : Effects.measurements -> string -> Wire.rgb option
(** The mean color of the box's pixels in range; [None] when none is, or the
    probe is missing or of another kind. *)

val red_excess : Wire.rgb -> float
(** How far red stands above both green and blue: the smaller of r - g and r -
    b. *)
