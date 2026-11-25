(** A box's colour statistics and the fork's tests for a solid colour on them:
    SolidColorTest's [is_white] and [is_grey] (CommonTools/Images/
    SolidColorTest.cpp) with their default stddev limit. *)

type stats = { mean : Wire.rgb; stddev : Wire.rgb }

val stats : Effects.measurements -> string -> stats option
(** The [color_stats] probe [id]'s result, when there is one. *)

val sum : Wire.rgb -> float
val distance : Wire.rgb -> Wire.rgb -> float

val white_min_sum : float
(** 500: a white's channels at least. *)

val solid_max_stddev : float
(** 10 *)

val is_white : stats -> bool
val is_grey : min_sum:float -> max_sum:float -> stats -> bool
