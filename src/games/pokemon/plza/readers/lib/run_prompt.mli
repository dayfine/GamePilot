(** Reader: the Run prompt of a wild battle, its minus button at the left of the
    screen. Ported from PokemonLZA_RunFromBattleDetector.cpp: a button detector
    for the minus button (PokemonLZA_ButtonDetector.cpp, {!Button_detector}) in
    the box (0.004456, 0.635499, 0.065062, 0.077655): blobs of the eight bright
    ranges (0x808080 to white up to 0xf0f0f0 to white) of at least 250 pixels
    and 15 x 15, scored under 80, aspect and fill within 0.8 to 1.25 of the
    template's (the fork's sizes at 4K scaled to 1080p).

    The fork has no test picture of it: its threshold is unchecked here on a
    console frame. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The probe, for a game picture at [picture] in the frame. *)

val shown : Effects.measurements -> bool
(** The minus button shows; [false] when the probe is missing. *)
