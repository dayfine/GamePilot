(** Reader: HOME's "Close software?" popup (X on a running game's tile). Ported
    from the fork's NintendoSwitch_CloseGameDetector.cpp with its boxes and
    thresholds, the boxes converted to the game picture as {!Home_screen}'s are
    ({!Picture_box}, all three lie inside the GBA app's picture). *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The three probes {!shown} needs, for a game picture at [picture] in the
    frame (the [hello]'s viewport). *)

val shown : Effects.measurements -> bool
(** The popup is up: its top and left edges one flat colour (white or grey), the
    text row below them not. [false] when a probe is missing. *)
