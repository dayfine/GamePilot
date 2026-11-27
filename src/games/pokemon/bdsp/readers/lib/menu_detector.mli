(** Reader: the BDSP overworld X menu.

    Ported from the fork's
    [SerialPrograms/Source/PokemonBDSP/Inference/PokemonBDSP_MenuDetector.cpp]
    ([MenuDetector]): five white vertical stripes between the menu icons plus a
    central cross box whose channel stddev sum is at least 100. *)

val probes :
  picture:Wire.box -> ?skip_new_banner:bool -> unit -> Wire.probe_spec list
(** The six probes {!shown} needs, relative to [picture]. *)

val shown : Effects.measurements -> bool
(** [true] when all five stripes are white and the central cross has stddev sum
    >= 100. [false] if any probe is missing. *)
