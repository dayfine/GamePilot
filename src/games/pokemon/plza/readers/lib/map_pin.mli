(** Reader: the player's pin on the full map (+ opens it), in the map's
    coordinates (the frame scaled to 800 x 450). Ported from
    PokemonLZA_MapPinReader.cpp ([plza/lean]): in Wild Zone 1's window on the
    map (x 240 to 540, y 170 to 290, with a margin round its outline), the
    pixels of the arrow's blue (0x0080e1 to 0x40c0ff: its white rim and the
    camera's cone (95, 200, 235) are out); of their blobs of 150 pixels and up
    (the arrow is 536 at 1080p, 465 with a corner under the zone's badge), the
    largest gives the pin.

    Where it differs: the fork takes the blob's centre of gravity, which
    [core.find@1] does not give; this takes its box's centre. For the dart the
    two are a few frame pixels apart, a pixel or two of the map's. *)

type point = { x : float; y : float }
(** Map coordinates: the frame scaled to 800 x 450. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probe, for a game picture at [picture] in the frame. *)

val of_blobs : Wire.Blob_find.blob list -> point option
(** The pin from the probe's blobs (frame pixels of the 1080p picture); for
    tests. *)

val read : Effects.measurements -> point option
(** The pin, or [None] when no blob is big enough or the probe is missing. *)
