(** Reader: the frame's mean colour in a 4 by 4 grid of cells, so two reads can
    tell whether the screen stayed still. The fork compares whole frames
    (CommonTools/ScreenEvents/ScreenEvents.cpp: a pixel RMSD under 2.0). No
    probe gives that: a probe measures one frame, and the RMSD needs the last
    frame's pixels, which the daemon does not keep (it would take a new probe
    kind that diffs against the previous frame). So this compares 16 cell means
    of two reads instead.

    Where it differs: a guess, not a port. Two frames are the same when no
    cell's channel mean moved by 2.0 or more; the threshold is not measured on
    console captures yet. *)

type t
(** One frame's cell means. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes {!read} needs, for a game picture at [picture] in the frame. *)

val read : Effects.measurements -> t option
(** The cells, or [None] when a probe is missing. *)

val same : t -> t -> bool
(** No cell moved by 2.0 or more. *)
