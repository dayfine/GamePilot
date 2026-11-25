(** Reader: the party bar's D-pad marker (up over the Pokémon sent out next,
    down under one sent out) under one of its six slots. Ported from
    PokemonLZA_OverworldPartySelectionDetector.cpp ([plza/lean]), the half of
    PokemonLZA_PartyBarDetector.cpp's [detect] that does not need an empty last
    slot: it still shows when the bar collapses to its lead icon (03.02b's
    plaza, console B, 2026-11-25), where the empty slots fade into light
    pavement.

    Each slot's box is (0.048 + 0.0398 i, 0.926, 0.017, 0.058), and in it a
    [ButtonDetector] for each of four templates (PokemonLZA_ButtonDetector.cpp):
    D-pad up and down, blobs of the eight bright ranges (0x808080 to white up to
    0xf0f0f0 to white) of at least 250 pixels and 15 x 15, scored under 80; and
    their black insides, blobs of the four dark ranges (black to 0x404040 up to
    black to 0x707070) of at least 25 pixels and 5 x 5, scored under 120. Sizes
    are the fork's at 4K scaled to 1080p; aspect and fill within 0.8 to 1.25 of
    the template's.

    Where it differs: the fork keeps which slot shows each marker; this says
    only whether any does. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The probes, for a game picture at [picture] in the frame: 24, four templates
    over six slots. *)

val shown : Effects.measurements -> bool
(** A marker shows under some slot; [false] when the probes are missing. *)
