(** Whether a box is one solid colour or white, from its [core.color_stats@1]
    result, as the fork tests it (CommonTools/Images/SolidColorTest.cpp) with
    the limits the PLZA readers pass ({!Switch_home.Solid_color} keeps the
    fork's defaults only). *)

type stats = Switch_home.Solid_color.stats
(** A box's mean and stddev per channel. *)

val probe :
  picture:Wire.box -> id:string -> Native_box.t -> Wire.probe_spec list
(** A [core.color_stats@1] probe over the box, every frame; none when the box is
    not wholly in the picture. *)

val read : Effects.measurements -> string -> stats option
(** The probe's result, when there is one. *)

val is_solid :
  ratio:Wire.rgb -> max_distance:float -> max_stddev_sum:float -> stats -> bool
(** Its stddevs add up to [max_stddev_sum] at most, and its mean's channel
    shares (each over their sum) lie within [max_distance] (Euclidean) of
    [ratio]. *)

val is_white : min_sum:float -> max_stddev_sum:float -> stats -> bool
(** Its mean adds up to [min_sum] at least, and it is solid grey (shares within
    0.08 of a third each). *)
