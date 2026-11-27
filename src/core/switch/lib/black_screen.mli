(** Reader: the black a launch shows once the game starts. Ported from
    CommonTools/VisualDetectors/BlackScreenDetector.cpp
    (https://github.com/PokemonAutomation/Arduino-Source), set up as
    NintendoSwitch_GameEntry.cpp watches for the black after a launch: the box
    (0.1, 0.15, 0.8, 0.7) of the frame, converted to the game picture
    ({!Picture_box}), its mean's channels 100 at most and their stddev 10 at
    most. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The one probe {!shown} needs, for a game picture at [picture] in the frame
    (the [hello]'s viewport). *)

val shown : Effects.measurements -> bool
(** The box is black: its channels' means summing to 100 at most, their stddevs
    to 10 at most. [false] when the probe is missing. *)
