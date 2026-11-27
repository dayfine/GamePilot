(** [core.find@1] probes over a {!Native_box.t}, and the blobs they read: the
    colour filter, waterfill and size filter
    (CommonTools/Images/WaterfillUtilities.cpp in
    https://github.com/PokemonAutomation/Arduino-Source), run in the daemon. *)

val probe :
  ?template:string ->
  picture:Wire.box ->
  id:string ->
  Native_box.t ->
  (Wire.Blob_find.params, string) result ->
  Wire.probe_spec list
(** The probe over the box, every frame; none when the box is not wholly in the
    picture or the params are refused. [template] asks for each blob's score. *)

val read : Effects.measurements -> string -> Wire.Blob_find.blob list
(** The probe's blobs; none when it is missing or of another kind. *)

type argb_range = { min : int; max : int }
(** A colour range written as the fork writes it, [0xAARRGGBB] at each end; the
    alpha is not tested (a frame is opaque). *)

val filter : argb_range -> Wire.Blob_find.filter
(** The range's red, green and blue. *)
