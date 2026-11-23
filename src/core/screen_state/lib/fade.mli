(** A fade to black or white, read from a [core.color_stats@1] probe over the
    middle of the screen. Game-agnostic: the thresholds are the fork's shared
    ones (CommonTools/ScreenEvents), used by every game there. *)

type t =
  | No_fade
  | Black  (** a door's black, or a cave mouth's dim fade *)
  | White  (** a cave exit's white *)

val middle_box : Wire.box
(** The middle 80% of the screen, the box the thresholds were set on. *)

val max_stddev_sum : float
(** A fade is uniform: the stddev of the three channels sums to at most this. A
    dim cave floor is textured and is no fade. *)

val max_dark_sum : float
(** Black up to this sum of the channel means: a cave mouth's fade is dim, not
    black. *)

val min_white_sum : float
(** White from this sum of the channel means. *)

val of_color_stats : mean:Wire.rgb -> stddev:Wire.rgb -> t
(** The fade a [core.color_stats@1] result over {!middle_box} shows. *)

val name : t -> string
(** ["black fade"], for the log. *)
