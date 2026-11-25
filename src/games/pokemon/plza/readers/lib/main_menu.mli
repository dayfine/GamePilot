(** Reader: the game's main menu (X): its entries on the left ("Boxes",
    "Satchel", "Pokédex", "Mable's Research"...) and the party on the right.
    Ported from PokemonLZA_MainMenuDetector.cpp ([plza/lean]): a
    [ButtonDetector] (PokemonLZA_ButtonDetector.cpp) for [ButtonRight] in the
    box (0.382, 0.081, 0.029, 0.056) and one for [ButtonB] (the "B Close" at the
    bottom right) in (0.87, 0.940, 0.077, 0.044), both showing: blobs of the
    eight bright ranges (0x808080 to white up to 0xf0f0f0 to white) of at least
    250 pixels and 25 x 25, scored under 70 (right) and 80 (B), aspect and fill
    within 0.8 to 1.25 of the template's (the fork's sizes at 4K scaled to
    1080p). *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The two probes, for a game picture at [picture] in the frame. *)

val shown : Effects.measurements -> bool
(** Both buttons show; [false] when a probe is missing. *)

val buttons : Effects.measurements -> bool * bool
(** Whether the right arrow and the B button each show. *)
