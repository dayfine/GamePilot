(** Reader: BDSP full-width white battle dialog box.

    Ported from the fork's
    [SerialPrograms/Source/PokemonBDSP/Inference/PokemonBDSP_DialogDetector.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source/blob/main/SerialPrograms/Source/PokemonBDSP/Inference/PokemonBDSP_DialogDetector.cpp):
    checks the white bottom and left-inner strips and high-contrast left/right
    frame borders of the wide battle dialog box. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The four color-statistics probes {!shown} needs, relative to [picture]. *)

val shown : Effects.measurements -> bool
(** [true] when the full-width white battle dialog box is visible on screen. *)
