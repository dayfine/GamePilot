(** Reader: the eye on a wild Pokemon's alert bar at the top of the screen.
    Ported from PokemonLZA_AlertEyeDetector.cpp ([plza/lean]): the
    AlertEyeMatcher template (AlertEye-Template.png, its shape the pixels from
    (200, 100, 100) to white) on blobs of the five bright ranges (0x808080 to
    white up to 0xc0c0c0 to white) of at least 300 pixels at 1080p, scored under
    60, aspect within 0.5 to 1.1 and fill within 0.75 to 1.1 of the template's;
    in the bar's box (0.485, 0.088, 0.029, 0.034), else the bigger eye's as the
    bar first shows (0.464, 0.142, 0.071, 0.074).

    Where it differs: the fork also keeps where the eye was; this says only
    whether it shows. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The probes, for a game picture at [picture] in the frame: one per box. *)

val shown : Effects.measurements -> bool
(** The eye shows in either box; [false] when the probes are missing. *)
