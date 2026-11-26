(** Reader: the BDSP overworld short white dialog box.

    Ported from the fork's
    [SerialPrograms/Source/PokemonBDSP/Inference/PokemonBDSP_DialogDetector.cpp]
    ([ShortDialogDetector]). *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The five probes {!shown} needs, relative to [picture]. *)

val shown : Effects.measurements -> bool
(** [true] when the short white dialog box is on screen. *)
