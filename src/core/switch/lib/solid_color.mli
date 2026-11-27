(** A box's colour statistics and the fork's tests for a solid colour on them:
    white and grey as CommonTools/Images/SolidColorTest.cpp tests them, with
    their default stddev limit. *)

type stats = { mean : Wire.rgb; stddev : Wire.rgb }
(** A box's mean colour and the stddev of each channel, 0 to 255. *)

val stats : Effects.measurements -> string -> stats option
(** The [color_stats] probe [id]'s result, when there is one. *)

val sum : Wire.rgb -> float
(** Its three channels added, as the fork's FloatPixel.h does for a colour. *)

val distance : Wire.rgb -> Wire.rgb -> float
(** The Euclidean distance between two colours (euclidean_distance). *)

val white_min_sum : float
(** 500: the least a white's channels add up to (is_white's min_rgb_sum). *)

val solid_max_stddev : float
(** 10: the most a solid colour's channel stddevs add up to (is_white's and
    is_grey's default max_stddev_sum). *)

val is_white : stats -> bool
(** is_white: bright ({!white_min_sum}), solid ({!solid_max_stddev}) and with
    its channels' shares within 0.08 of a third each. *)

val is_grey : min_sum:float -> max_sum:float -> stats -> bool
(** is_grey: its channels adding up to between [min_sum] and [max_sum], solid
    ({!solid_max_stddev}), and, when not near black (100 or more), its channels'
    shares within 0.1 of a third each. *)
