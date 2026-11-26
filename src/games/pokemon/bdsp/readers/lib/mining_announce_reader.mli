(** Reader: the opening Grand Underground mining wall announcement dialog
    ([確認到牆壁中有N個 / 強烈反應！], [N ∈ {2, 3, 4}]).

    Measured from Console A captures ([run-60/frames/000039.jpg] and
    [run-73/frames/000005.jpg] = [2]; [run-75/frames/000102.jpg] and
    [run-75/frames/000194.jpg] = [3]; [run-74/frames/000095.jpg] and
    [run-74/frames/000321.jpg] = [4]): the numeral sits at normalized box
    [x = 0.4250..0.4375], [y = 0.8389..0.8778] as crisp dark text on the white
    dialog background. Four dark-ink [Wire.color_count_probe] sub-boxes
    (top-left, mid-left, bottom-left, bottom-right) separate [2], [3], and [4]
    with wide margin. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The four dark-ink sub-box probes covering the announced-item digit inside
    the opening mining dialog, relative to [picture]. *)

val classify_shares : tl:float -> ml:float -> bl:float -> br:float -> int option
(** Pure classifier mapping the four sub-box dark-ink shares to [Some 2],
    [Some 3], [Some 4], or [None] when no valid digit is visible. *)

val read : Effects.measurements -> int option
(** Read the announced buried-item count ([2], [3], or [4]) from daemon
    measurements, or [None] if the opening dialog digit is not visible. *)
