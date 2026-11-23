(** Color tests on a [core.color_stats@1] result, ported from the fork's
    CommonTools/Images/SolidColorTest: is a box one flat color, white, grey?
    Readers combine these on several thin boxes along a window's edges. *)

type stats = { mean : Wire.rgb; stddev : Wire.rgb }
(** A box's per-channel mean and stddev, 0..255. *)

val read : Effects.measurements -> string -> stats option
(** The color stats of the probe with this id; [None] when it is missing or of
    another kind. *)

val holds : Effects.measurements -> string -> (stats -> bool) -> bool
(** [holds m id test] is [test] on the probe's stats; false when it is missing.
*)

val sum : Wire.rgb -> float
(** r + g + b. *)

val is_solid :
  ratio:Wire.rgb -> max_distance:float -> max_stddev_sum:float -> stats -> bool
(** Flat (stddev sum at most [max_stddev_sum]) and of this hue: the mean's
    channel shares (each over their sum) lie within [max_distance] (Euclidean)
    of [ratio]. *)

val is_white : ?min_sum:float -> ?max_stddev_sum:float -> stats -> bool
(** Flat grey whose channel sum is at least [min_sum] (default 500; stddev sum
    default 10, channel shares within 0.08 of a third each). *)

val is_grey :
  min_sum:float -> max_sum:float -> max_stddev_sum:float -> stats -> bool
(** Flat, channel sum in [[min_sum, max_sum]], and neutral (shares within 0.1 of
    a third each) unless darker than a sum of 100, where hue is unstable. *)
