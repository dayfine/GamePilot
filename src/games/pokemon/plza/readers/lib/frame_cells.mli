(** Reader: the frame's mean colour in a 4 by 4 grid of cells, so two reads can
    tell whether the screen stayed still. The fork compares whole frames
    ([same_screen] in CommonTools/ScreenEvents/ScreenEvents.cpp: a pixel RMSD
    under 2.0); no probe gives that, so this compares cell means instead.

    Where it differs: a guess, not a port. Two frames are the same when no
    cell's channel mean moved by {!max_change} or more; the threshold is not
    measured on console captures yet. *)

type t
(** One frame's cell means. *)

val max_change : float
(** 2.0: a channel mean moving this much in any cell is a change. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes {!read} needs, for a game picture at [picture] in the frame. *)

val read : Effects.measurements -> t option
(** The cells, or [None] when a probe is missing. *)

val same : t -> t -> bool
(** No cell moved by {!max_change} or more. *)
